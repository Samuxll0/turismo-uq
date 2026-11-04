-- ============================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- ENTREGA 3 (PUNTO 2): CONCURRENCIA, BLOQUEO DE FILA (SELECT ... FOR UPDATE)
--                      Y EXPERIMENTO DOCUMENTADO CON DOS SESIONES
-- ARCHIVO: database/entrega 3/02_concurrencia_bloqueos.sql
-- ============================================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = TURISMO_UQ;

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- ============================================================================
-- 1. PROCEDIMIENTO CON CONTROL DE CONCURRENCIA PESIMISTA (SELECT ... FOR UPDATE)
-- ============================================================================
-- Explicacion Tecnica (Comparativa Antes vs Despues):
--
-- [COMPORTAMIENTO ANTES - Sin SELECT ... FOR UPDATE]:
--   En el nivel de aislamiento por defecto de Oracle (READ COMMITTED), las lecturas
--   no bloquean lecturas ni escrituras. Si la Sesion 1 y la Sesion 2 consultan al
--   mismo tiempo si la habitacion #1 esta libre (SELECT COUNT(*) FROM RESERVA_HABITACION...),
--   ambas leen 0 solapamientos porque ninguna ha hecho COMMIT todavia (fenomeno de
--   carrera critica / Read Skew). Ambas proceden a insertar la reserva para las
--   mismas fechas.
--
-- [COMPORTAMIENTO DESPUES - Con SELECT ... FOR UPDATE]:
--   Antes de verificar disponibilidad, el procedimiento ejecuta:
--     SELECT capacidad INTO v_capacidad
--     FROM TURISMO_UQ.HABITACION
--     WHERE id_habitacion = p_id_habitacion
--     FOR UPDATE WAIT 5;
--   Esto serializa el acceso a nivel de fila (Row-Level Exclusive Lock TX) sobre
--   la habitacion especifica sin bloquear las demas 399 habitaciones del hotel:
--   1) Sesion 1 adquiere el bloqueo exclusivo sobre la fila de HABITACION.
--   2) Sesion 2 intenta reservar la misma habitacion y queda en espera (WAIT)
--      bajo el evento 'enq: TX - row lock contention'.
--   3) Sesion 1 inserta la reserva y ejecuta COMMIT, liberando el bloqueo.
--   4) Sesion 2 despierta del FOR UPDATE, ejecuta la consulta de solapamiento
--      (que ahora ve el COMMIT de la Sesion 1) y rechaza limpiamente con ORA-20003.
-- ============================================================================

CREATE OR REPLACE PROCEDURE TURISMO_UQ.sp_reservar_con_bloqueo(
    p_id_cliente     IN  NUMBER,
    p_id_habitacion  IN  NUMBER,
    p_fecha_in       IN  DATE,
    p_fecha_out      IN  DATE,
    p_num_huespedes  IN  NUMBER,
    p_segundos_wait  IN  NUMBER DEFAULT 5,
    o_id_reserva     OUT NUMBER,
    o_total          OUT NUMBER,
    o_mensaje        OUT VARCHAR2
) IS
    v_fecha_in        DATE := TRUNC(p_fecha_in);
    v_fecha_out       DATE := TRUNC(p_fecha_out);
    v_capacidad       NUMBER;
    v_numero_hab      VARCHAR2(50);
    v_count_cliente   NUMBER;
    v_solapados       NUMBER;
    v_noches          NUMBER;
    v_precio_promedio NUMBER(12,2);
    v_total_calculado NUMBER(14,2);

    -- Excepcion estandar de Oracle para ORA-30006 (resource busy; acquire with WAIT timeout expired)
    -- y ORA-00054 (resource busy and acquire with NOWAIT specified)
    e_recurso_ocupado_wait   EXCEPTION;
    e_recurso_ocupado_nowait EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_recurso_ocupado_wait, -30006);
    PRAGMA EXCEPTION_INIT(e_recurso_ocupado_nowait, -54);
BEGIN
    -- 1. Validaciones basicas de fechas y cliente
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
        RAISE_APPLICATION_ERROR(-20005, 'El cliente no existe en el sistema');
    END IF;

    -- ========================================================================
    -- 2. ADQUISICION DE BLOQUEO DE FILA (SELECT ... FOR UPDATE)
    -- ========================================================================
    -- Bloquea exclusivamente la fila de la habitacion solicitada.
    -- Si otra sesion ya esta procesando una reserva sobre esta misma habitacion,
    -- la sesion actual espera hasta 5 segundos antes de continuar o abortar.
    BEGIN
        IF NVL(p_segundos_wait, 5) <= 0 THEN
            SELECT capacidad, numero_nombre
            INTO v_capacidad, v_numero_hab
            FROM TURISMO_UQ.HABITACION
            WHERE id_habitacion = p_id_habitacion
            FOR UPDATE NOWAIT;
        ELSE
            SELECT capacidad, numero_nombre
            INTO v_capacidad, v_numero_hab
            FROM TURISMO_UQ.HABITACION
            WHERE id_habitacion = p_id_habitacion
            FOR UPDATE WAIT 5;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20004, 'Habitacion no encontrada en el sistema');
        WHEN e_recurso_ocupado_wait OR e_recurso_ocupado_nowait THEN
            RAISE_APPLICATION_ERROR(-20008, 'CONCURRENCIA DETECTADA: La habitacion #' || p_id_habitacion ||
                ' esta bloqueada (SELECT FOR UPDATE) por otra sesion activa. Intente nuevamente.');
    END;

    -- 3. Validar capacidad con la fila ya bloqueada
    IF p_num_huespedes > v_capacidad OR p_num_huespedes <= 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Capacidad maxima de la habitacion excedida');
    END IF;

    -- 4. Verificar disponibilidad (ahora libre de condiciones de carrera)
    SELECT COUNT(*) INTO v_solapados
    FROM TURISMO_UQ.RESERVA_HABITACION rh
    JOIN TURISMO_UQ.RESERVA r ON rh.id_reserva = r.id_reserva
    WHERE rh.id_habitacion = p_id_habitacion
      AND r.estado != 'CANCELADA'
      AND r.fecha_check_in < v_fecha_out
      AND r.fecha_check_out > v_fecha_in;

    IF v_solapados > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Habitacion no disponible: otra sesion confirmo primero este rango de fechas');
    END IF;

    -- 5. Calcular estadia e insertar reserva
    v_total_calculado := TURISMO_UQ.PKG_TURISMO_RESERVAS.fn_valor_estadia(
        p_id_habitacion => p_id_habitacion,
        p_fecha_in      => v_fecha_in,
        p_fecha_out     => v_fecha_out
    );
    v_noches          := v_fecha_out - v_fecha_in;
    v_precio_promedio := ROUND(v_total_calculado / v_noches, 2);

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

    o_total   := v_total_calculado;
    o_mensaje := 'Reserva #' || o_id_reserva || ' confirmada con bloqueo exclusivo (SELECT FOR UPDATE) sobre Habitacion ' || v_numero_hab;

    -- 6. Liberar el bloqueo de fila confirmando la transaccion
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_reservar_con_bloqueo;
/

-- ============================================================================
-- 2. GUIA DOCUMENTADA DEL LABORATORIO EN VIVO (DOS SESIONES SIMULTANEAS)
-- ============================================================================
/*
===============================================================================
LABORATORIO DE CONCURRENCIA CON DOS SESIONES (SQL*Plus / SQL Developer)
===============================================================================

--- PASO 1: En SESION 1 (Terminal A) ---
-- La Sesion 1 inicia la transaccion y adquiere el bloqueo exclusivo de fila
-- sobre la habitacion ID = 1 sin hacer COMMIT todavia:

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = TURISMO_UQ;

SELECT id_habitacion, numero_nombre, capacidad
FROM TURISMO_UQ.HABITACION
WHERE id_habitacion = 1
FOR UPDATE;

-- Resultado en Sesion 1:
-- Fila retornada e inmediatamente bloqueada con candado TX (Row-X / SX).


--- PASO 2: En SESION 2 (Terminal B - Simultaneamente) ---
-- La Sesion 2 intenta reservar o adquirir el candado sobre la misma habitacion ID = 1:

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = TURISMO_UQ;

-- Intento A (con NOWAIT / WAIT 5 en nuestro procedimiento):
DECLARE
    v_id_res NUMBER;
    v_total  NUMBER;
    v_msg    VARCHAR2(500);
BEGIN
    TURISMO_UQ.sp_reservar_con_bloqueo(
        p_id_cliente    => 2,
        p_id_habitacion => 1,
        p_fecha_in      => DATE '2027-09-10',
        p_fecha_out     => DATE '2027-09-14',
        p_num_huespedes => 2,
        p_segundos_wait => 3,
        o_id_reserva    => v_id_res,
        o_total         => v_total,
        o_mensaje       => v_msg
    );
END;
/
-- Resultado en Sesion 2:
-- La Sesion 2 queda bloqueada esperando durante 3 segundos ('enq: TX - row lock contention').
-- Si Sesion 1 no hace COMMIT en 3s, Sesion 2 recibe ORA-20008 (Concurrencia detectada).
-- Si Sesion 1 confirma su reserva dentro de la ventana, Sesion 2 despierta,
-- detecta el solapamiento recien confirmado y recibe ORA-20003 (Habitacion no disponible).


--- PASO 3: Consulta de Monitoreo de Bloqueos (V$LOCK y V$SESSION) ---
-- Ejecutar como SYSDBA mientras la Sesion 2 esta esperando a la Sesion 1:

SELECT
    s1.sid AS sid_bloqueador,
    s1.serial# AS serial_bloqueador,
    s1.username AS usuario_bloqueador,
    s2.sid AS sid_esperando,
    s2.serial# AS serial_esperando,
    s2.event AS evento_espera,
    s2.seconds_in_wait AS segundos_esperando
FROM v$lock l1
JOIN v$session s1 ON l1.sid = s1.sid
JOIN v$lock l2 ON l1.id1 = l2.id1 AND l1.id2 = l2.id2
JOIN v$session s2 ON l2.sid = s2.sid
WHERE l1.block = 1 AND l2.request > 0;


--- PASO 4: En SESION 1 (Terminal A) ---
-- Liberar el candado:
COMMIT;
===============================================================================
*/

PROMPT Procedimiento sp_reservar_con_bloqueo compilado exitosamente.
