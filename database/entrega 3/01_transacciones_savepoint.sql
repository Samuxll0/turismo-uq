-- ============================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- ENTREGA 3 (PUNTO 1): TRANSACCIONES ATOMICAS CON SAVEPOINT Y ROLLBACK PARCIAL
-- ARCHIVO: database/entrega 3/01_transacciones_savepoint.sql
-- ============================================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = TURISMO_UQ;

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- Asegurar compatibilidad del check constraint de metodos de pago en base existente y limpia
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE TURISMO_UQ.PAGO DROP CONSTRAINT chk_pago_metodo';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE TURISMO_UQ.PAGO ADD CONSTRAINT chk_pago_metodo CHECK (metodo_pago IN (''TARJETA'', ''TARJETA_CREDITO'', ''TARJETA_DEBITO'', ''TRANSFERENCIA'', ''EFECTIVO'', ''PSE''))';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- ============================================================================
-- 1. PROCEDIMIENTO TRANSACCIONAL: sp_reserva_transaccional_pago
-- ============================================================================
-- Proposito:
--   Registrar de forma atomica una reserva de alojamiento junto con su pago.
--   Utiliza SAVEPOINT sp_reserva_creada inmediatamente despues de insertar
--   el encabezado de la reserva y la asignacion de habitacion.
--   Si el registro del pago falla (por monto invalido, medio no soportado o
--   simulacion de fallo en pasarela), se ejecuta ROLLBACK TO sp_reserva_creada,
--   deshaciendo unicamente la operacion de pago y conservando la reserva en
--   estado 'PENDIENTE' para no perder el cupo del cliente.
-- ============================================================================

CREATE OR REPLACE PROCEDURE TURISMO_UQ.sp_reserva_transaccional_pago(
    p_id_cliente         IN  NUMBER,
    p_id_habitacion      IN  NUMBER,
    p_fecha_in           IN  DATE,
    p_fecha_out          IN  DATE,
    p_num_huespedes      IN  NUMBER,
    p_monto_pago         IN  NUMBER,
    p_metodo_pago        IN  VARCHAR2 DEFAULT 'TARJETA',
    p_simular_fallo_pago IN  VARCHAR2 DEFAULT 'N',
    o_id_reserva         OUT NUMBER,
    o_id_pago            OUT NUMBER,
    o_total_reserva      OUT NUMBER,
    o_estado_reserva     OUT VARCHAR2,
    o_estado_pago        OUT VARCHAR2,
    o_rollback_parcial   OUT VARCHAR2,
    o_mensaje            OUT VARCHAR2
) IS
    v_fecha_in        DATE := TRUNC(p_fecha_in);
    v_fecha_out       DATE := TRUNC(p_fecha_out);
    v_capacidad       NUMBER;
    v_count_cliente   NUMBER;
    v_solapados       NUMBER;
    v_noches          NUMBER;
    v_precio_promedio NUMBER(12,2);
    v_total_calculado NUMBER(14,2);
    v_monto_efectivo  NUMBER(14,2);
BEGIN
    -- 1. Validaciones previas de integridad y reglas de negocio
    IF v_fecha_out <= v_fecha_in THEN
        RAISE_APPLICATION_ERROR(-20001, 'Check-out debe ser posterior al check-in');
    END IF;

    IF v_fecha_in < TRUNC(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20006, 'No se pueden generar reservas anteriores a la fecha actual');
    END IF;

    SELECT COUNT(*) INTO v_count_cliente
    FROM TURISMO_UQ.CLIENTE
    WHERE id_cliente = p_id_cliente;

    IF v_count_cliente = 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'El cliente especificado no existe en el sistema');
    END IF;

    BEGIN
        SELECT capacidad INTO v_capacidad
        FROM TURISMO_UQ.HABITACION
        WHERE id_habitacion = p_id_habitacion;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20004, 'La habitacion indicada no existe en el sistema');
    END;

    IF p_num_huespedes > v_capacidad OR p_num_huespedes <= 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'El numero de huespedes (' || p_num_huespedes || ') excede la capacidad maxima (' || v_capacidad || ')');
    END IF;

    SELECT COUNT(*) INTO v_solapados
    FROM TURISMO_UQ.RESERVA_HABITACION rh
    JOIN TURISMO_UQ.RESERVA r ON rh.id_reserva = r.id_reserva
    WHERE rh.id_habitacion = p_id_habitacion
      AND r.estado != 'CANCELADA'
      AND r.fecha_check_in < v_fecha_out
      AND r.fecha_check_out > v_fecha_in;

    IF v_solapados > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Habitacion no disponible en el rango de fechas solicitado');
    END IF;

    -- 2. Calculo del valor de la estadia multi-temporada
    v_total_calculado := TURISMO_UQ.PKG_TURISMO_RESERVAS.fn_valor_estadia(
        p_id_habitacion => p_id_habitacion,
        p_fecha_in      => v_fecha_in,
        p_fecha_out     => v_fecha_out
    );
    v_noches          := v_fecha_out - v_fecha_in;
    v_precio_promedio := ROUND(v_total_calculado / v_noches, 2);
    o_total_reserva   := v_total_calculado;

    -- 3. Insercion de RESERVA (inicialmente en estado 'PENDIENTE' hasta confirmar el pago)
    INSERT INTO TURISMO_UQ.RESERVA (
        fecha_creacion,
        fecha_check_in,
        fecha_check_out,
        total,
        estado,
        id_cliente
    ) VALUES (
        SYSDATE,
        v_fecha_in,
        v_fecha_out,
        v_total_calculado,
        'PENDIENTE',
        p_id_cliente
    ) RETURNING id_reserva INTO o_id_reserva;

    -- 4. Insercion del detalle en RESERVA_HABITACION
    INSERT INTO TURISMO_UQ.RESERVA_HABITACION (
        id_reserva,
        id_habitacion,
        precio_unitario,
        subtotal
    ) VALUES (
        o_id_reserva,
        p_id_habitacion,
        v_precio_promedio,
        v_total_calculado
    );

    -- ========================================================================
    -- 5. PUNTO DE SALVAGUARDA (SAVEPOINT)
    -- ========================================================================
    -- Hasta este punto la reserva y su asignacion de habitacion son validas.
    -- Si la transaccion de pago posterior falla, desharemos unicamente desde aqui.
    SAVEPOINT sp_reserva_creada;

    -- ========================================================================
    -- 6. SUB-BLOQUE TRANSACCIONAL PARA EL REGISTRO DEL PAGO
    -- ========================================================================
    BEGIN
        v_monto_efectivo := NVL(p_monto_pago, v_total_calculado);

        -- Simulacion explicita de rechazo bancario / pasarela o validacion de monto
        IF UPPER(NVL(p_simular_fallo_pago, 'N')) = 'S' THEN
            RAISE_APPLICATION_ERROR(-20007, 'Rechazo en pasarela bancaria: Fondos insuficientes o timeout de red');
        END IF;

        IF v_monto_efectivo <= 0 THEN
            RAISE_APPLICATION_ERROR(-20007, 'El monto del pago debe ser estrictamente mayor a cero');
        END IF;

        -- Insertar el registro de pago
        INSERT INTO TURISMO_UQ.PAGO (
            id_reserva,
            monto,
            fecha_pago,
            metodo_pago,
            estado
        ) VALUES (
            o_id_reserva,
            v_monto_efectivo,
            SYSDATE,
            UPPER(NVL(p_metodo_pago, 'TARJETA')),
            'APROBADO'
        ) RETURNING id_pago INTO o_id_pago;

        -- Actualizar la reserva a CONFIRMADA tras el exito del pago
        UPDATE TURISMO_UQ.RESERVA
        SET estado = 'CONFIRMADA'
        WHERE id_reserva = o_id_reserva;

        o_estado_reserva   := 'CONFIRMADA';
        o_estado_pago      := 'APROBADO';
        o_rollback_parcial := 'N';
        o_mensaje          := 'Transaccion atomica completada: Reserva #' || o_id_reserva ||
                              ' CONFIRMADA y Pago #' || o_id_pago || ' registrado por $' ||
                              TO_CHAR(v_monto_efectivo, 'FM999,999,999');

        -- Confirmar toda la transaccion (Reserva + Habitacion + Pago)
        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            -- ================================================================
            -- DEMOSTRACION DE ROLLBACK PARCIAL HACIA EL SAVEPOINT
            -- ================================================================
            -- Se revierte cualquier cambio posterior a sp_reserva_creada (el pago),
            -- pero se conserva intacta la reserva en estado 'PENDIENTE'.
            ROLLBACK TO SAVEPOINT sp_reserva_creada;

            o_id_pago          := NULL;
            o_estado_reserva   := 'PENDIENTE';
            o_estado_pago      := 'RECHAZADO';
            o_rollback_parcial := 'S';
            o_mensaje          := 'ROLLBACK PARCIAL EJECUTADO (SAVEPOINT sp_reserva_creada): ' ||
                                  'Se revirtio el pago por error [' || SQLERRM || '], ' ||
                                  'pero la Reserva #' || o_id_reserva || ' quedo resguardada en estado PENDIENTE.';

            -- Confirmar el trabajo previo al SAVEPOINT (Reserva + Habitacion quedan persistidas)
            COMMIT;
    END;

EXCEPTION
    WHEN OTHERS THEN
        -- Si falla antes del SAVEPOINT (ej. fechas invalidas, sobrecupo, solapamiento),
        -- se ejecuta ROLLBACK total y se propaga la excepcion de negocio.
        ROLLBACK;
        RAISE;
END sp_reserva_transaccional_pago;
/

PROMPT Procedimiento sp_reserva_transaccional_pago compilado exitosamente.
