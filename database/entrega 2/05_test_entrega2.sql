-- ========================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- ENTREGA 2: BATERIA EXHAUSTIVA DE PRUEBAS PL/SQL
-- ARCHIVO: database/entrega 2/05_test_entrega2.sql
-- ========================================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = TURISMO_UQ;

SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT ========================================================================
PROMPT INICIO DE BATERIA DE PRUEBAS - ENTREGA 2 (TURISMO_UQ)
PROMPT ========================================================================

-- ------------------------------------------------------------------------
-- PRUEBA A: fn_valor_estadia con fechas cruzando temporada alta y baja
-- ------------------------------------------------------------------------
DECLARE
    v_total NUMBER;
    v_baja  NUMBER;
    v_alta  NUMBER;
BEGIN
    SELECT precio_noche INTO v_baja FROM TURISMO_UQ.TARIFA WHERE id_habitacion = 1 AND id_temporada = 1;
    SELECT precio_noche INTO v_alta FROM TURISMO_UQ.TARIFA WHERE id_habitacion = 1 AND id_temporada = 2;

    -- Rango: 2024-03-21 al 2024-03-26 (5 noches)
    -- Semana Santa inicia el 2024-03-23:
    -- Noches 21 y 22: Temporada Baja (2 x v_baja)
    -- Noches 23, 24 y 25: Temporada Alta (3 x v_alta)
    v_total := TURISMO_UQ.PKG_TURISMO_RESERVAS.fn_valor_estadia(1, DATE '2024-03-21', DATE '2024-03-26');

    DBMS_OUTPUT.PUT_LINE('Prueba A) fn_valor_estadia:');
    DBMS_OUTPUT.PUT_LINE('  - Tarifa Baja: $' || TO_CHAR(v_baja, '999,999,999') || ' | Tarifa Alta: $' || TO_CHAR(v_alta, '999,999,999'));
    DBMS_OUTPUT.PUT_LINE('  - Total calculado para 5 noches: $' || TO_CHAR(v_total, '999,999,999'));
    IF v_total = (2 * v_baja + 3 * v_alta) THEN
        DBMS_OUTPUT.PUT_LINE('  --> [RESULTADO: EXITOSO]');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  --> [RESULTADO: ERROR EN CALCULO]');
    END IF;
END;
/

-- ------------------------------------------------------------------------
-- PRUEBA B: sp_crear_reserva caso exitoso
-- ------------------------------------------------------------------------
DECLARE
    v_id_reserva NUMBER;
    v_total      NUMBER;
BEGIN
    TURISMO_UQ.PKG_TURISMO_RESERVAS.sp_crear_reserva(
        p_id_cliente    => 1,
        p_id_habitacion => 1,
        p_fecha_in      => DATE '2027-05-10',
        p_fecha_out     => DATE '2027-05-15',
        p_num_huespedes => 2,
        o_id_reserva    => v_id_reserva,
        o_total         => v_total
    );

    DBMS_OUTPUT.PUT_LINE('Prueba B) sp_crear_reserva (Exitoso):');
    DBMS_OUTPUT.PUT_LINE('  - Reserva creada con ID: ' || v_id_reserva || ' | Total: $' || TO_CHAR(v_total, '999,999,999'));
    DBMS_OUTPUT.PUT_LINE('  --> [RESULTADO: EXITOSO]');
END;
/

-- ------------------------------------------------------------------------
-- PRUEBA C: sp_crear_reserva validacion ORA-20001 (Checkout previo o igual)
-- ------------------------------------------------------------------------
DECLARE
    v_id_reserva NUMBER;
    v_total      NUMBER;
BEGIN
    TURISMO_UQ.PKG_TURISMO_RESERVAS.sp_crear_reserva(
        p_id_cliente    => 1,
        p_id_habitacion => 1,
        p_fecha_in      => DATE '2027-06-15',
        p_fecha_out     => DATE '2027-06-10',
        p_num_huespedes => 2,
        o_id_reserva    => v_id_reserva,
        o_total         => v_total
    );
    DBMS_OUTPUT.PUT_LINE('Prueba C) Error: debio fallar con ORA-20001 pero continuo.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20001 THEN
            DBMS_OUTPUT.PUT_LINE('Prueba C) ORA-20001 capturado correctamente: ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('  --> [RESULTADO: EXITOSO]');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Prueba C) Codigo inesperado: ' || SQLCODE || ' - ' || SQLERRM);
        END IF;
END;
/

-- ------------------------------------------------------------------------
-- PRUEBA D: sp_crear_reserva validacion ORA-20002 (Capacidad excedida)
-- ------------------------------------------------------------------------
DECLARE
    v_id_reserva NUMBER;
    v_total      NUMBER;
BEGIN
    TURISMO_UQ.PKG_TURISMO_RESERVAS.sp_crear_reserva(
        p_id_cliente    => 1,
        p_id_habitacion => 1,
        p_fecha_in      => DATE '2027-07-01',
        p_fecha_out     => DATE '2027-07-05',
        p_num_huespedes => 99, -- Excede capacidad maxima
        o_id_reserva    => v_id_reserva,
        o_total         => v_total
    );
    DBMS_OUTPUT.PUT_LINE('Prueba D) Error: debio fallar con ORA-20002 pero continuo.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20002 THEN
            DBMS_OUTPUT.PUT_LINE('Prueba D) ORA-20002 capturado correctamente: ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('  --> [RESULTADO: EXITOSO]');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Prueba D) Codigo inesperado: ' || SQLCODE || ' - ' || SQLERRM);
        END IF;
END;
/

-- ------------------------------------------------------------------------
-- PRUEBA E: sp_crear_reserva validacion ORA-20003 (Solapamiento con Reserva de Prueba B)
-- ------------------------------------------------------------------------
DECLARE
    v_id_reserva NUMBER;
    v_total      NUMBER;
BEGIN
    -- Se intenta reservar la habitacion 1 entre 2027-05-12 y 2027-05-14 (solapada con 2027-05-10 a 2027-05-15)
    TURISMO_UQ.PKG_TURISMO_RESERVAS.sp_crear_reserva(
        p_id_cliente    => 2,
        p_id_habitacion => 1,
        p_fecha_in      => DATE '2027-05-12',
        p_fecha_out     => DATE '2027-05-14',
        p_num_huespedes => 1,
        o_id_reserva    => v_id_reserva,
        o_total         => v_total
    );
    DBMS_OUTPUT.PUT_LINE('Prueba E) Error: debio fallar con ORA-20003 pero continuo.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20003 THEN
            DBMS_OUTPUT.PUT_LINE('Prueba E) ORA-20003 capturado correctamente: ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('  --> [RESULTADO: EXITOSO]');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Prueba E) Codigo inesperado: ' || SQLCODE || ' - ' || SQLERRM);
        END IF;
END;
/

-- ------------------------------------------------------------------------
-- PRUEBA F: sp_liquidacion_mensual verificando ejecucion del cursor y persistencia
-- ------------------------------------------------------------------------
DECLARE
    v_cursor SYS_REFCURSOR;
    v_anio   NUMBER;
    v_mes    NUMBER;
    v_id_aloj NUMBER;
    v_nom    VARCHAR2(100);
    v_res    NUMBER;
    v_hosp   NUMBER;
    v_serv   NUMBER;
    v_tot    NUMBER;
    v_filas  NUMBER := 0;
    v_pers   NUMBER := 0;
BEGIN
    TURISMO_UQ.PKG_TURISMO_RESERVAS.sp_liquidacion_mensual(
        p_mes            => 7,
        p_anio           => 2025,
        p_id_alojamiento => NULL,
        o_resultado      => v_cursor
    );

    DBMS_OUTPUT.PUT_LINE('Prueba F) Consumo de Cursor de Liquidacion Mensual (Julio 2025 - Top 3):');
    LOOP
        FETCH v_cursor INTO v_anio, v_mes, v_id_aloj, v_nom, v_res, v_hosp, v_serv, v_tot;
        EXIT WHEN v_cursor%NOTFOUND OR v_filas >= 3;
        v_filas := v_filas + 1;
        DBMS_OUTPUT.PUT_LINE('  Alojamiento [' || v_id_aloj || '] ' || v_nom || ' | Reservas: ' || v_res || ' | Total: $' || TO_CHAR(v_tot, '999,999,999'));
    END LOOP;
    CLOSE v_cursor;

    SELECT COUNT(*) INTO v_pers
    FROM TURISMO_UQ.LIQUIDACION_MENSUAL_HISTORICO
    WHERE mes = 7 AND anio = 2025;

    DBMS_OUTPUT.PUT_LINE('  - Registros persistidos en LIQUIDACION_MENSUAL_HISTORICO: ' || v_pers);
    IF v_pers > 0 THEN
        DBMS_OUTPUT.PUT_LINE('  --> [RESULTADO: EXITOSO]');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  --> [RESULTADO: NO SE ENCONTRARON REGISTROS PERSISTIDOS]');
    END IF;
END;
/

-- ------------------------------------------------------------------------
-- PRUEBA G: Verificacion de Auditoria de TARIFA tras UPDATE de prueba
-- ------------------------------------------------------------------------
DECLARE
    v_precio_orig NUMBER;
    v_aud_accion  VARCHAR2(10);
    v_aud_old     NUMBER;
    v_aud_new     NUMBER;
    v_aud_usr     VARCHAR2(60);
BEGIN
    SELECT precio_noche INTO v_precio_orig
    FROM TURISMO_UQ.TARIFA
    WHERE id_habitacion = 1 AND id_temporada = 1;

    -- Aplicar modificacion
    UPDATE TURISMO_UQ.TARIFA
    SET precio_noche = precio_noche + 10000
    WHERE id_habitacion = 1 AND id_temporada = 1;

    -- Verificar insercion en AUDITORIA_TARIFA
    SELECT accion, precio_anterior, precio_nuevo, usuario
    INTO v_aud_accion, v_aud_old, v_aud_new, v_aud_usr
    FROM (
        SELECT accion, precio_anterior, precio_nuevo, usuario
        FROM TURISMO_UQ.AUDITORIA_TARIFA
        WHERE id_habitacion = 1 AND id_temporada = 1
        ORDER BY id_auditoria DESC
    )
    WHERE ROWNUM = 1;

    DBMS_OUTPUT.PUT_LINE('Prueba G) Auditoria de Tarifas:');
    DBMS_OUTPUT.PUT_LINE('  - Accion: ' || v_aud_accion || ' | Anterior: $' || v_aud_old || ' | Nuevo: $' || v_aud_new || ' | Usuario: ' || v_aud_usr);

    -- Restaurar precio original
    UPDATE TURISMO_UQ.TARIFA
    SET precio_noche = v_precio_orig
    WHERE id_habitacion = 1 AND id_temporada = 1;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('  - Precio restaurado exitosamente.');
    DBMS_OUTPUT.PUT_LINE('  --> [RESULTADO: EXITOSO]');
END;
/

PROMPT ========================================================================
PROMPT FIN DE BATERIA DE PRUEBAS - ENTREGA 2 (TURISMO_UQ)
PROMPT ========================================================================
