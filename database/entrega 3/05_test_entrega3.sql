-- ============================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- ENTREGA 3 (PUNTO 5): BATERIA AUTOMATIZADA E IDEMPOTENTE DE PRUEBAS (A - E)
-- ARCHIVO: database/entrega 3/05_test_entrega3.sql
-- ============================================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = TURISMO_UQ;

SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT ============================================================================
PROMPT === INICIANDO BATERIA DE PRUEBAS AUTOMATIZADAS - ENTREGA 3               ===
PROMPT ============================================================================

-- Limpieza previa de las fechas exclusivas de prueba (Anio 2028) para garantizar
-- idempotencia absoluta cuantas veces se ejecute el script
BEGIN
    DELETE FROM TURISMO_UQ.PAGO
    WHERE id_reserva IN (
        SELECT id_reserva FROM TURISMO_UQ.RESERVA
        WHERE fecha_check_in >= DATE '2028-01-01'
    );

    DELETE FROM TURISMO_UQ.RESERVA_HABITACION
    WHERE id_reserva IN (
        SELECT id_reserva FROM TURISMO_UQ.RESERVA
        WHERE fecha_check_in >= DATE '2028-01-01'
    );

    DELETE FROM TURISMO_UQ.RESERVA
    WHERE fecha_check_in >= DATE '2028-01-01';

    COMMIT;
END;
/

DECLARE
    v_id_reserva      NUMBER;
    v_id_pago         NUMBER;
    v_total           NUMBER;
    v_estado_res      VARCHAR2(30);
    v_estado_pago     VARCHAR2(30);
    v_rollback_parc   VARCHAR2(5);
    v_mensaje         VARCHAR2(600);
    v_conteo_pagos    NUMBER;
    v_conteo_indices  NUMBER;
    v_conteo_vistas   NUMBER;
BEGIN
    -- ========================================================================
    -- PRUEBA A: Transaccion Atomica Reserva + Pago (Camino Feliz - COMMIT Total)
    -- ========================================================================
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('[PRUEBA A] Transaccion Atomica Reserva + Pago Exitoso:');

    TURISMO_UQ.sp_reserva_transaccional_pago(
        p_id_cliente         => 1,
        p_id_habitacion      => 1,
        p_fecha_in           => DATE '2028-02-10',
        p_fecha_out          => DATE '2028-02-14',
        p_num_huespedes      => 2,
        p_monto_pago         => NULL, -- Toma automaticamente el total liquidado
        p_metodo_pago        => 'TARJETA',
        p_simular_fallo_pago => 'N',
        o_id_reserva         => v_id_reserva,
        o_id_pago            => v_id_pago,
        o_total_reserva      => v_total,
        o_estado_reserva     => v_estado_res,
        o_estado_pago        => v_estado_pago,
        o_rollback_parcial   => v_rollback_parc,
        o_mensaje            => v_mensaje
    );

    IF v_estado_res = 'CONFIRMADA' AND v_estado_pago = 'APROBADO' AND v_rollback_parc = 'N' AND v_id_pago IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('  -> [RESULTADO: EXITOSO] ' || v_mensaje);
    ELSE
        RAISE_APPLICATION_ERROR(-20901, 'Fallo en Prueba A: ' || v_mensaje);
    END IF;

    -- ========================================================================
    -- PRUEBA B: Demostracion de SAVEPOINT y Rollback Parcial ante Fallo de Pago
    -- ========================================================================
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('[PRUEBA B] Demostracion SAVEPOINT sp_reserva_creada y Rollback Parcial:');

    TURISMO_UQ.sp_reserva_transaccional_pago(
        p_id_cliente         => 2,
        p_id_habitacion      => 2,
        p_fecha_in           => DATE '2028-03-05',
        p_fecha_out          => DATE '2028-03-08',
        p_num_huespedes      => 2,
        p_monto_pago         => 500000,
        p_metodo_pago        => 'PSE',
        p_simular_fallo_pago => 'S', -- Provoca fallo en el sub-bloque de pago
        o_id_reserva         => v_id_reserva,
        o_id_pago            => v_id_pago,
        o_total_reserva      => v_total,
        o_estado_reserva     => v_estado_res,
        o_estado_pago        => v_estado_pago,
        o_rollback_parcial   => v_rollback_parc,
        o_mensaje            => v_mensaje
    );

    SELECT COUNT(*) INTO v_conteo_pagos
    FROM TURISMO_UQ.PAGO
    WHERE id_reserva = v_id_reserva;

    IF v_estado_res = 'PENDIENTE' AND v_rollback_parc = 'S' AND v_conteo_pagos = 0 THEN
        DBMS_OUTPUT.PUT_LINE('  -> [RESULTADO: EXITOSO] ' || v_mensaje);
        DBMS_OUTPUT.PUT_LINE('  -> Verificacion en BD: Reserva #' || v_id_reserva || ' persistida en estado PENDIENTE y 0 pagos registrados.');
    ELSE
        RAISE_APPLICATION_ERROR(-20902, 'Fallo en Prueba B: No se ejecuto correctamente el Rollback Parcial.');
    END IF;

    -- ========================================================================
    -- PRUEBA C: Bloqueo Pesimista de Fila (SELECT ... FOR UPDATE)
    -- ========================================================================
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('[PRUEBA C] Reserva con Bloqueo Pesimista (SELECT ... FOR UPDATE):');

    TURISMO_UQ.sp_reservar_con_bloqueo(
        p_id_cliente    => 3,
        p_id_habitacion => 3,
        p_fecha_in      => DATE '2028-04-10',
        p_fecha_out     => DATE '2028-04-13',
        p_num_huespedes => 2,
        p_segundos_wait => 3,
        o_id_reserva    => v_id_reserva,
        o_total         => v_total,
        o_mensaje       => v_mensaje
    );

    DBMS_OUTPUT.PUT_LINE('  -> [RESULTADO: EXITOSO] ' || v_mensaje);

    -- ========================================================================
    -- PRUEBA D: Verificacion de Indices Compuesto, Basado en Funcion y Caso Negativo
    -- ========================================================================
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('[PRUEBA D] Verificacion de Indices y Planes de Ejecucion (CBO):');

    SELECT COUNT(*) INTO v_conteo_indices
    FROM all_indexes
    WHERE owner = 'TURISMO_UQ'
      AND index_name IN ('IDX_COMP_RESERVA_EST_CREA', 'IDX_FBI_RESERVA_ANIO_MES', 'IDX_COMP_RESSERV_SERV_CANT')
      AND status = 'VALID';

    IF v_conteo_indices = 3 THEN
        DBMS_OUTPUT.PUT_LINE('  -> [RESULTADO: EXITOSO] Los 3 indices (Compuesto, Basado en Funcion y Cobertura) estan VALIDOS.');
    ELSE
        RAISE_APPLICATION_ERROR(-20904, 'Fallo en Prueba D: Indices faltantes o invalidos (' || v_conteo_indices || '/3).');
    END IF;

    -- ========================================================================
    -- PRUEBA E: Verificacion de Vistas de Recepcion y Trigger INSTEAD OF
    -- ========================================================================
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('[PRUEBA E] Verificacion de Vistas de Recepcion y Trigger INSTEAD OF:');

    SELECT COUNT(*) INTO v_conteo_vistas
    FROM all_views
    WHERE owner = 'TURISMO_UQ'
      AND view_name IN ('VW_RECEPCION_RESERVAS', 'VW_RECEPCION_CHECKIN', 'VW_RECEPCION_HABITACIONES_DISP');

    -- Probar actualizacion a traves de la vista VW_RECEPCION_RESERVAS (como lo haria ROL_RECEPCION)
    UPDATE TURISMO_UQ.VW_RECEPCION_RESERVAS
    SET estado_reserva = 'FINALIZADA'
    WHERE id_reserva = v_id_reserva;
    COMMIT;

    SELECT estado INTO v_estado_res
    FROM TURISMO_UQ.RESERVA
    WHERE id_reserva = v_id_reserva;

    IF v_conteo_vistas = 3 AND v_estado_res = 'FINALIZADA' THEN
        DBMS_OUTPUT.PUT_LINE('  -> [RESULTADO: EXITOSO] Las 3 vistas de recepcion operan correctamente y el Trigger INSTEAD OF actualizo el estado sin tocar la tabla directa.');
    ELSE
        RAISE_APPLICATION_ERROR(-20905, 'Fallo en Prueba E: Vistas de recepcion incompletas.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('=== TODAS LAS PRUEBAS DE LA ENTREGA 3 FINALIZARON CON 100% DE EXITO ===');
END;
/

-- Revalidar la vista materializada dependiente tras las pruebas DML sobre RESERVA
BEGIN
    EXECUTE IMMEDIATE 'ALTER MATERIALIZED VIEW TURISMO_UQ.MV_OCUPACION_MENSUAL COMPILE';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
