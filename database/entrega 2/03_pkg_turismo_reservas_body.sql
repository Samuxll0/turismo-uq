-- ========================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- ENTREGA 2: CUERPO DEL PAQUETE PKG_TURISMO_RESERVAS
-- ARCHIVO: 03_pkg_turismo_reservas_body.sql
-- ========================================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = TURISMO_UQ;

CREATE OR REPLACE PACKAGE BODY TURISMO_UQ.PKG_TURISMO_RESERVAS AS

    -- ====================================================================
    -- FUNCION fn_valor_estadia
    -- ====================================================================
    FUNCTION fn_valor_estadia(
        p_id_habitacion IN NUMBER,
        p_fecha_in      IN DATE,
        p_fecha_out     IN DATE
    ) RETURN NUMBER IS
        v_fecha_in      DATE := TRUNC(p_fecha_in);
        v_fecha_out     DATE := TRUNC(p_fecha_out);
        v_fecha_actual  DATE;
        v_tarifa_baja   NUMBER(12,2);
        v_tarifa_alta   NUMBER(12,2);
        v_total         NUMBER(14,2) := 0;
        v_es_alta       NUMBER;
        v_count_hab     NUMBER;
    BEGIN
        -- 1. Validacion de coherencia cronologica
        IF v_fecha_out <= v_fecha_in THEN
            RAISE_APPLICATION_ERROR(-20001, 'Check-out debe ser posterior a check-in');
        END IF;

        -- 2. Verificacion de existencia de la habitacion
        SELECT COUNT(*)
        INTO v_count_hab
        FROM TURISMO_UQ.HABITACION
        WHERE id_habitacion = p_id_habitacion;

        IF v_count_hab = 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Habitacion no encontrada en el sistema');
        END IF;

        -- 3. Consulta de tarifas (Baja y Alta) para la habitacion
        BEGIN
            SELECT precio_noche INTO v_tarifa_baja
            FROM TURISMO_UQ.TARIFA
            WHERE id_habitacion = p_id_habitacion AND id_temporada = 1;

            SELECT precio_noche INTO v_tarifa_alta
            FROM TURISMO_UQ.TARIFA
            WHERE id_habitacion = p_id_habitacion AND id_temporada = 2;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20004, 'Tarifas no configuradas para la habitacion');
        END;

        -- 4. Iteracion dia por dia (cada noche entre fecha_in y fecha_out - 1)
        v_fecha_actual := v_fecha_in;
        WHILE v_fecha_actual < v_fecha_out LOOP
            -- Verificar si la fecha actual coincide con un periodo de Temporada Alta
            SELECT COUNT(*)
            INTO v_es_alta
            FROM TURISMO_UQ.PERIODO_TEMPORADA
            WHERE id_temporada = 2
              AND v_fecha_actual >= TRUNC(fecha_inicio)
              AND v_fecha_actual <= TRUNC(fecha_fin);

            IF v_es_alta > 0 THEN
                v_total := v_total + v_tarifa_alta;
            ELSE
                v_total := v_total + v_tarifa_baja;
            END IF;

            v_fecha_actual := v_fecha_actual + 1;
        END LOOP;

        RETURN v_total;
    END fn_valor_estadia;

    -- ====================================================================
    -- PROCEDIMIENTO sp_crear_reserva
    -- ====================================================================
    PROCEDURE sp_crear_reserva(
        p_id_cliente    IN NUMBER,
        p_id_habitacion IN NUMBER,
        p_fecha_in      IN DATE,
        p_fecha_out     IN DATE,
        p_num_huespedes IN NUMBER,
        o_id_reserva    OUT NUMBER,
        o_total         OUT NUMBER
    ) IS
        v_fecha_in        DATE := TRUNC(p_fecha_in);
        v_fecha_out       DATE := TRUNC(p_fecha_out);
        v_capacidad       NUMBER;
        v_count_cliente   NUMBER;
        v_solapados       NUMBER;
        v_noches          NUMBER;
        v_precio_promedio NUMBER(12,2);
        v_total_calculado NUMBER(14,2);
    BEGIN
        -- 1. Validar fechas de estadia
        IF v_fecha_out <= v_fecha_in THEN
            RAISE_APPLICATION_ERROR(-20001, 'Check-out anterior o igual al check-in');
        END IF;

        -- Validar que la fecha de check-in no sea anterior a la fecha actual (reservas en el pasado)
        IF v_fecha_in < TRUNC(SYSDATE) THEN
            RAISE_APPLICATION_ERROR(-20006, 'No se pueden generar reservas anteriores a la fecha actual');
        END IF;

        -- 2. Validar existencia del cliente
        SELECT COUNT(*)
        INTO v_count_cliente
        FROM TURISMO_UQ.CLIENTE
        WHERE id_cliente = p_id_cliente;

        IF v_count_cliente = 0 THEN
            RAISE_APPLICATION_ERROR(-20005, 'Cliente no existe en el sistema');
        END IF;

        -- 3. Validar existencia y capacidad de la habitacion
        BEGIN
            SELECT capacidad
            INTO v_capacidad
            FROM TURISMO_UQ.HABITACION
            WHERE id_habitacion = p_id_habitacion;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20004, 'Habitacion no encontrada en el sistema');
        END;

        IF p_num_huespedes > v_capacidad OR p_num_huespedes <= 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Capacidad excedida');
        END IF;

        -- 4. Validar disponibilidad (ausencia de solapamiento con reservas activas)
        SELECT COUNT(*)
        INTO v_solapados
        FROM TURISMO_UQ.RESERVA_HABITACION rh
        JOIN TURISMO_UQ.RESERVA r ON rh.id_reserva = r.id_reserva
        WHERE rh.id_habitacion = p_id_habitacion
          AND r.estado != 'CANCELADA'
          AND r.fecha_check_in < v_fecha_out
          AND r.fecha_check_out > v_fecha_in;

        IF v_solapados > 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Habitacion no disponible');
        END IF;

        -- 5. Calcular valor total de la estadia mediante fn_valor_estadia
        v_total_calculado := fn_valor_estadia(p_id_habitacion, v_fecha_in, v_fecha_out);
        v_noches          := v_fecha_out - v_fecha_in;
        v_precio_promedio := ROUND(v_total_calculado / v_noches, 2);

        -- 6. Insertar en RESERVA y obtener ID generado por secuencia/identity
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
            'CONFIRMADA',
            p_id_cliente
        ) RETURNING id_reserva INTO o_id_reserva;

        -- 7. Insertar el detalle en RESERVA_HABITACION
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

        o_total := v_total_calculado;
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END sp_crear_reserva;

    -- ====================================================================
    -- PROCEDIMIENTO sp_liquidacion_mensual
    -- ====================================================================
    PROCEDURE sp_liquidacion_mensual(
        p_mes            IN NUMBER,
        p_anio           IN NUMBER,
        p_id_alojamiento IN NUMBER DEFAULT NULL,
        o_resultado      OUT SYS_REFCURSOR
    ) IS
        -- Cursor explicito parametrizado masivo
        CURSOR c_liquidacion(cp_mes NUMBER, cp_anio NUMBER, cp_alojamiento NUMBER) IS
            WITH serv_reserva AS (
                SELECT id_reserva, SUM(subtotal) AS total_servicios
                FROM TURISMO_UQ.RESERVA_SERVICIO
                GROUP BY id_reserva
            ),
            reserva_alojamiento AS (
                SELECT 
                    a.id_alojamiento,
                    a.nombre AS nombre_alojamiento,
                    r.id_reserva,
                    rh.subtotal AS total_hospedaje,
                    NVL(sr.total_servicios, 0) AS total_servicios
                FROM TURISMO_UQ.RESERVA r
                JOIN TURISMO_UQ.RESERVA_HABITACION rh ON r.id_reserva = rh.id_reserva
                JOIN TURISMO_UQ.HABITACION h          ON rh.id_habitacion = h.id_habitacion
                JOIN TURISMO_UQ.ALOJAMIENTO a         ON h.id_alojamiento = a.id_alojamiento
                LEFT JOIN serv_reserva sr             ON r.id_reserva = sr.id_reserva
                WHERE EXTRACT(MONTH FROM r.fecha_check_in) = cp_mes
                  AND EXTRACT(YEAR FROM r.fecha_check_in) = cp_anio
                  AND (cp_alojamiento IS NULL OR a.id_alojamiento = cp_alojamiento)
                  AND r.estado != 'CANCELADA'
            )
            SELECT 
                id_alojamiento,
                nombre_alojamiento,
                COUNT(id_reserva) AS total_reservas,
                NVL(SUM(total_hospedaje), 0) AS total_hospedaje,
                NVL(SUM(total_servicios), 0) AS total_servicios,
                NVL(SUM(total_hospedaje + total_servicios), 0) AS total_ingresos
            FROM reserva_alojamiento
            GROUP BY id_alojamiento, nombre_alojamiento
            ORDER BY total_ingresos DESC;

        TYPE t_liq_tab IS TABLE OF c_liquidacion%ROWTYPE;
        v_liq_tab t_liq_tab;
    BEGIN
        -- 1. Validaciones de parametros
        IF p_mes < 1 OR p_mes > 12 THEN
            RAISE_APPLICATION_ERROR(-20005, 'Mes invalido. Debe estar comprendido entre 1 y 12');
        END IF;

        IF p_anio < 2000 OR p_anio > 2100 THEN
            RAISE_APPLICATION_ERROR(-20005, 'Anio invalido fuera de rango');
        END IF;

        -- 2. Procesamiento masivo con Cursor explicito y BULK COLLECT
        OPEN c_liquidacion(p_mes, p_anio, p_id_alojamiento);
        FETCH c_liquidacion BULK COLLECT INTO v_liq_tab;
        CLOSE c_liquidacion;

        -- 3. Persistencia en LIQUIDACION_MENSUAL_HISTORICO con MERGE masivo
        IF v_liq_tab.COUNT > 0 THEN
            FORALL i IN 1..v_liq_tab.COUNT
                MERGE INTO TURISMO_UQ.LIQUIDACION_MENSUAL_HISTORICO tgt
                USING (
                    SELECT 
                        p_anio                       AS anio,
                        p_mes                        AS mes,
                        v_liq_tab(i).id_alojamiento  AS id_alojamiento,
                        v_liq_tab(i).total_reservas  AS total_reservas,
                        v_liq_tab(i).total_hospedaje AS total_hospedaje,
                        v_liq_tab(i).total_servicios AS total_servicios,
                        v_liq_tab(i).total_ingresos  AS total_ingresos
                    FROM dual
                ) src
                ON (tgt.anio = src.anio AND tgt.mes = src.mes AND tgt.id_alojamiento = src.id_alojamiento)
                WHEN MATCHED THEN
                    UPDATE SET 
                        tgt.total_reservas    = src.total_reservas,
                        tgt.total_hospedaje   = src.total_hospedaje,
                        tgt.total_servicios   = src.total_servicios,
                        tgt.total_ingresos    = src.total_ingresos,
                        tgt.fecha_liquidacion = SYSDATE
                WHEN NOT MATCHED THEN
                    INSERT (anio, mes, id_alojamiento, total_reservas, total_hospedaje, total_servicios, total_ingresos, fecha_liquidacion)
                    VALUES (src.anio, src.mes, src.id_alojamiento, src.total_reservas, src.total_hospedaje, src.total_servicios, src.total_ingresos, SYSDATE);

            COMMIT;
        END IF;

        -- 4. Apertura del SYS_REFCURSOR para entrega a la aplicacion cliente
        OPEN o_resultado FOR
            WITH serv_reserva AS (
                SELECT id_reserva, SUM(subtotal) AS total_servicios
                FROM TURISMO_UQ.RESERVA_SERVICIO
                GROUP BY id_reserva
            ),
            reserva_alojamiento AS (
                SELECT 
                    a.id_alojamiento,
                    a.nombre AS nombre_alojamiento,
                    r.id_reserva,
                    rh.subtotal AS total_hospedaje,
                    NVL(sr.total_servicios, 0) AS total_servicios
                FROM TURISMO_UQ.RESERVA r
                JOIN TURISMO_UQ.RESERVA_HABITACION rh ON r.id_reserva = rh.id_reserva
                JOIN TURISMO_UQ.HABITACION h          ON rh.id_habitacion = h.id_habitacion
                JOIN TURISMO_UQ.ALOJAMIENTO a         ON h.id_alojamiento = a.id_alojamiento
                LEFT JOIN serv_reserva sr             ON r.id_reserva = sr.id_reserva
                WHERE EXTRACT(MONTH FROM r.fecha_check_in) = p_mes
                  AND EXTRACT(YEAR FROM r.fecha_check_in) = p_anio
                  AND (p_id_alojamiento IS NULL OR a.id_alojamiento = p_id_alojamiento)
                  AND r.estado != 'CANCELADA'
            )
            SELECT 
                p_anio AS anio,
                p_mes  AS mes,
                id_alojamiento,
                nombre_alojamiento,
                COUNT(id_reserva) AS total_reservas,
                NVL(SUM(total_hospedaje), 0) AS total_hospedaje,
                NVL(SUM(total_servicios), 0) AS total_servicios,
                NVL(SUM(total_hospedaje + total_servicios), 0) AS total_ingresos
            FROM reserva_alojamiento
            GROUP BY id_alojamiento, nombre_alojamiento
            ORDER BY total_ingresos DESC;

    END sp_liquidacion_mensual;

END PKG_TURISMO_RESERVAS;
/
