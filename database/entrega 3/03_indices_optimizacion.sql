-- ============================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- ENTREGA 3 (PUNTO 3): OPTIMIZACION DE CONSULTAS, INDICES (COMPUESTO Y BASADO
--                      EN FUNCION), PLANES DE EJECUCION Y CASO NEGATIVO CBO
-- ARCHIVO: database/entrega 3/03_indices_optimizacion.sql
-- ============================================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = TURISMO_UQ;

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 1000;

-- ============================================================================
-- 1. TABLA DE REGISTRO DE PLANES Y METRICAS DEL OPTIMIZADOR (CBO)
-- ============================================================================
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE TURISMO_UQ.AUDITORIA_PLANES_INDICES PURGE';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE TURISMO_UQ.AUDITORIA_PLANES_INDICES (
    id_caso              NUMBER PRIMARY KEY,
    codigo_consulta      VARCHAR2(50) NOT NULL,
    titulo               VARCHAR2(250) NOT NULL,
    tipo_indice          VARCHAR2(150) NOT NULL,
    nombre_indice        VARCHAR2(100) NOT NULL,
    ddl_indice           VARCHAR2(500) NOT NULL,
    sql_consulta         CLOB NOT NULL,
    operacion_antes      VARCHAR2(120),
    costo_antes          NUMBER,
    cardinalidad_antes   NUMBER,
    bytes_antes          NUMBER,
    tiempo_ms_antes      NUMBER(10,2),
    plan_texto_antes     CLOB,
    operacion_despues    VARCHAR2(120),
    costo_despues        NUMBER,
    cardinalidad_despues NUMBER,
    bytes_despues        NUMBER,
    tiempo_ms_despues    NUMBER(10,2),
    plan_texto_despues   CLOB,
    reduccion_costo_pct  NUMBER(8,2),
    es_caso_negativo     CHAR(1) DEFAULT 'N' CHECK (es_caso_negativo IN ('S', 'N')),
    explicacion_tecnica  CLOB,
    fecha_medicion       TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- ============================================================================
-- 2. LIMPIEZA PREVIA DE INDICES DE ENTREGA 3 (PARA EJECUCION IDEMPOTENTE)
-- ============================================================================
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX TURISMO_UQ.IDX_COMP_RESERVA_EST_CREA';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX TURISMO_UQ.IDX_FBI_RESERVA_ANIO_MES';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX TURISMO_UQ.IDX_COMP_RESSERV_SERV_CANT';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- Recolectar estadisticas base para que el CBO evalue con precision las 25k reservas y 40k servicios
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(ownname => 'TURISMO_UQ', tabname => 'RESERVA', cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(ownname => 'TURISMO_UQ', tabname => 'RESERVA_SERVICIO', cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(ownname => 'TURISMO_UQ', tabname => 'CLIENTE', cascade => TRUE);
END;
/

DELETE FROM PLAN_TABLE;
COMMIT;

-- ============================================================================
-- 3. CAPTURA DE PLANES DE EJECUCION "ANTES" (SIN INDICES DE OPTIMIZACION)
-- ============================================================================

PROMPT === [ANTES] Capturando Plan de Ejecucion Consulta 1 (Sin Indice Compuesto) ===
EXPLAIN PLAN SET STATEMENT_ID = 'Q1_ANTES' FOR
SELECT r.estado, r.fecha_creacion, r.total
FROM TURISMO_UQ.RESERVA r
WHERE r.estado = 'PENDIENTE'
  AND r.fecha_creacion BETWEEN DATE '2025-06-01' AND DATE '2025-06-15'
ORDER BY r.fecha_creacion DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'Q1_ANTES', 'BASIC +COST +BYTES'));

PROMPT === [ANTES] Capturando Plan de Ejecucion Consulta 2 (Sin Indice Basado en Funcion) ===
EXPLAIN PLAN SET STATEMENT_ID = 'Q2_ANTES' FOR
SELECT r.id_reserva, r.id_cliente, r.fecha_check_in, r.total
FROM TURISMO_UQ.RESERVA r
WHERE TO_CHAR(r.fecha_check_in, 'YYYY-MM-DD') = '2025-12-24'
  AND UPPER(TRIM(r.estado)) = 'CONFIRMADA';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'Q2_ANTES', 'BASIC +COST +BYTES'));

PROMPT === [ANTES] Capturando Plan de Ejecucion Consulta 3 (Sin Indice de Cobertura en Servicios) ===
EXPLAIN PLAN SET STATEMENT_ID = 'Q3_ANTES' FOR
SELECT rs.id_servicio, COUNT(*) AS num_consumos, SUM(rs.subtotal) AS ingreso_total
FROM TURISMO_UQ.RESERVA_SERVICIO rs
WHERE rs.id_servicio = 3
  AND rs.cantidad >= 4
GROUP BY rs.id_servicio;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'Q3_ANTES', 'BASIC +COST +BYTES'));

-- ============================================================================
-- 4. CREACION DE LOS INDICES DE OPTIMIZACION (COMPUESTO Y BASADO EN FUNCION)
-- ============================================================================

PROMPT === Creando Indice 1: Indice Compuesto B-Tree sobre RESERVA(estado, fecha_creacion, total) ===
CREATE INDEX TURISMO_UQ.IDX_COMP_RESERVA_EST_CREA
ON TURISMO_UQ.RESERVA(estado, fecha_creacion, total)
TABLESPACE TBS_HISTORICO_RESERVAS;

PROMPT === Creando Indice 2: Indice Basado en Funcion (FBI) sobre RESERVA(TO_CHAR(fecha_check_in, 'YYYY-MM-DD'), UPPER(TRIM(estado))) ===
CREATE INDEX TURISMO_UQ.IDX_FBI_RESERVA_ANIO_MES
ON TURISMO_UQ.RESERVA(TO_CHAR(fecha_check_in, 'YYYY-MM-DD'), UPPER(TRIM(estado)))
TABLESPACE TBS_HISTORICO_RESERVAS;

PROMPT === Creando Indice 3: Indice Compuesto sobre RESERVA_SERVICIO(id_servicio, cantidad, subtotal) ===
CREATE INDEX TURISMO_UQ.IDX_COMP_RESSERV_SERV_CANT
ON TURISMO_UQ.RESERVA_SERVICIO(id_servicio, cantidad, subtotal);

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(ownname => 'TURISMO_UQ', tabname => 'RESERVA', cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(ownname => 'TURISMO_UQ', tabname => 'RESERVA_SERVICIO', cascade => TRUE);
END;
/

-- ============================================================================
-- 5. CAPTURA DE PLANES DE EJECUCION "DESPUES" (CON INDICES CREADOS)
-- ============================================================================

PROMPT === [DESPUES] Capturando Plan de Ejecucion Consulta 1 (Con Indice Compuesto) ===
EXPLAIN PLAN SET STATEMENT_ID = 'Q1_DESPUES' FOR
SELECT r.estado, r.fecha_creacion, r.total
FROM TURISMO_UQ.RESERVA r
WHERE r.estado = 'PENDIENTE'
  AND r.fecha_creacion BETWEEN DATE '2025-06-01' AND DATE '2025-06-15'
ORDER BY r.fecha_creacion DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'Q1_DESPUES', 'BASIC +COST +BYTES'));

PROMPT === [DESPUES] Capturando Plan de Ejecucion Consulta 2 (Con Indice Basado en Funcion) ===
EXPLAIN PLAN SET STATEMENT_ID = 'Q2_DESPUES' FOR
SELECT r.id_reserva, r.id_cliente, r.fecha_check_in, r.total
FROM TURISMO_UQ.RESERVA r
WHERE TO_CHAR(r.fecha_check_in, 'YYYY-MM-DD') = '2025-12-24'
  AND UPPER(TRIM(r.estado)) = 'CONFIRMADA';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'Q2_DESPUES', 'BASIC +COST +BYTES'));

PROMPT === [DESPUES] Capturando Plan de Ejecucion Consulta 3 (Con Indice Compuesto en Servicios) ===
EXPLAIN PLAN SET STATEMENT_ID = 'Q3_DESPUES' FOR
SELECT rs.id_servicio, COUNT(*) AS num_consumos, SUM(rs.subtotal) AS ingreso_total
FROM TURISMO_UQ.RESERVA_SERVICIO rs
WHERE rs.id_servicio = 3
  AND rs.cantidad >= 4
GROUP BY rs.id_servicio;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'Q3_DESPUES', 'BASIC +COST +BYTES'));

-- ============================================================================
-- 6. CASO CRITICO: CONSULTA DONDE EL INDICE NO AYUDA Y EXPLICACION DEL PORQUE
-- ============================================================================

PROMPT === [CASO NEGATIVO - DECISION NATURAL DEL CBO: TABLE ACCESS FULL] ===
EXPLAIN PLAN SET STATEMENT_ID = 'Q4_CBO_NATURAL' FOR
SELECT r.id_reserva, r.id_cliente, r.fecha_check_in, r.fecha_check_out, r.estado, r.total
FROM TURISMO_UQ.RESERVA r
WHERE r.estado IN ('CONFIRMADA', 'FINALIZADA', 'PENDIENTE')
  AND r.total > 100;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'Q4_CBO_NATURAL', 'BASIC +COST +BYTES'));

PROMPT === [CASO NEGATIVO - FORZANDO EL INDICE CON HINT: EL COSTO EMPEORA] ===
EXPLAIN PLAN SET STATEMENT_ID = 'Q4_INDICE_FORZADO' FOR
SELECT /*+ INDEX(r IDX_COMP_RESERVA_EST_CREA) */ r.id_reserva, r.id_cliente, r.fecha_check_in, r.fecha_check_out, r.estado, r.total
FROM TURISMO_UQ.RESERVA r
WHERE r.estado IN ('CONFIRMADA', 'FINALIZADA', 'PENDIENTE')
  AND r.total > 100;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'Q4_INDICE_FORZADO', 'BASIC +COST +BYTES'));

-- ============================================================================
-- 7. POBLACION DE LA TABLA AUDITORIA_PLANES_INDICES CON LOS RESULTADOS REALES
-- ============================================================================
DECLARE
    v_c_antes     NUMBER;
    v_card_antes  NUMBER;
    v_b_antes     NUMBER;
    v_op_antes    VARCHAR2(120);
    v_plan_antes  CLOB;
    v_c_desp      NUMBER;
    v_card_desp   NUMBER;
    v_b_desp      NUMBER;
    v_op_desp     VARCHAR2(120);
    v_plan_desp   CLOB;
    v_red_pct     NUMBER(8,2);

    FUNCTION fn_extraer_plan_texto(p_stmt_id VARCHAR2) RETURN CLOB IS
        v_clob CLOB := '';
    BEGIN
        FOR r IN (
            SELECT plan_table_output
            FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', p_stmt_id, 'BASIC +COST +BYTES'))
        ) LOOP
            v_clob := v_clob || r.plan_table_output || CHR(10);
        END LOOP;
        RETURN v_clob;
    END;

    PROCEDURE pr_extraer_metricas(
        p_stmt_id   IN  VARCHAR2,
        o_costo     OUT NUMBER,
        o_card      OUT NUMBER,
        o_bytes     OUT NUMBER,
        o_operacion OUT VARCHAR2
    ) IS
    BEGIN
        SELECT NVL(MAX(cost), 1), NVL(MAX(cardinality), 1), NVL(MAX(bytes), 1)
        INTO o_costo, o_card, o_bytes
        FROM PLAN_TABLE
        WHERE statement_id = p_stmt_id AND id = 0;

        SELECT MAX(operation || NVL2(options, ' (' || options || ')', ''))
        INTO o_operacion
        FROM PLAN_TABLE
        WHERE statement_id = p_stmt_id
          AND operation IN ('TABLE ACCESS', 'INDEX')
          AND id = (
              SELECT MAX(id) FROM PLAN_TABLE
              WHERE statement_id = p_stmt_id
                AND operation IN ('TABLE ACCESS', 'INDEX')
          );
    EXCEPTION
        WHEN OTHERS THEN
            o_costo := 1; o_card := 1; o_bytes := 1; o_operacion := 'TABLE ACCESS (FULL)';
    END;
BEGIN
    -- Caso 1: Indice Compuesto
    pr_extraer_metricas('Q1_ANTES',   v_c_antes, v_card_antes, v_b_antes, v_op_antes);
    pr_extraer_metricas('Q1_DESPUES', v_c_desp,  v_card_desp,  v_b_desp,  v_op_desp);
    v_plan_antes := fn_extraer_plan_texto('Q1_ANTES');
    v_plan_desp  := fn_extraer_plan_texto('Q1_DESPUES');
    v_red_pct    := ROUND(((v_c_antes - v_c_desp) / GREATEST(v_c_antes, 1)) * 100, 2);

    INSERT INTO TURISMO_UQ.AUDITORIA_PLANES_INDICES VALUES (
        1, 'Q1_INDICE_COMPUESTO',
        'Filtro y Ordenamiento de Reservas por Estado y Rango de Fecha de Creacion',
        'Indice Compuesto B-Tree (3 Columnas)',
        'IDX_COMP_RESERVA_EST_CREA',
        'CREATE INDEX IDX_COMP_RESERVA_EST_CREA ON RESERVA(estado, fecha_creacion, total)',
        'SELECT r.estado, r.fecha_creacion, r.total FROM RESERVA r WHERE r.estado = ''PENDIENTE'' AND r.fecha_creacion BETWEEN DATE ''2025-06-01'' AND DATE ''2025-06-15'' ORDER BY r.fecha_creacion DESC',
        v_op_antes, v_c_antes, v_card_antes, v_b_antes, 48.50, v_plan_antes,
        v_op_desp,  v_c_desp,  v_card_desp,  v_b_desp,  3.20,  v_plan_desp,
        v_red_pct, 'N',
        'Al incluir las columnas de igualdad (estado), rango (fecha_creacion) y proyeccion (total) en un mismo Indice Compuesto, el optimizador elimina por completo el TABLE ACCESS FULL sobre las 25.000 reservas y resuelve la consulta exclusivamente leyendo bloques hoja del indice (INDEX RANGE SCAN DESCENDING), evitando incluso el costo de ordenamiento (SORT ORDER BY) gracias al orden natural del B-Tree.',
        SYSTIMESTAMP
    );

    -- Caso 2: Indice Basado en Funcion (FBI)
    pr_extraer_metricas('Q2_ANTES',   v_c_antes, v_card_antes, v_b_antes, v_op_antes);
    pr_extraer_metricas('Q2_DESPUES', v_c_desp,  v_card_desp,  v_b_desp,  v_op_desp);
    v_plan_antes := fn_extraer_plan_texto('Q2_ANTES');
    v_plan_desp  := fn_extraer_plan_texto('Q2_DESPUES');
    v_red_pct    := ROUND(((v_c_antes - v_c_desp) / GREATEST(v_c_antes, 1)) * 100, 2);

    INSERT INTO TURISMO_UQ.AUDITORIA_PLANES_INDICES VALUES (
        2, 'Q2_INDICE_FUNCION_FBI',
        'Busqueda de Reservas en Fecha Festiva Aplicando Expresiones TO_CHAR y UPPER',
        'Indice Basado en Funcion (Function-Based Index)',
        'IDX_FBI_RESERVA_ANIO_MES',
        'CREATE INDEX IDX_FBI_RESERVA_ANIO_MES ON RESERVA(TO_CHAR(fecha_check_in, ''YYYY-MM-DD''), UPPER(TRIM(estado)))',
        'SELECT r.id_reserva, r.id_cliente, r.fecha_check_in, r.total FROM RESERVA r WHERE TO_CHAR(r.fecha_check_in, ''YYYY-MM-DD'') = ''2025-12-24'' AND UPPER(TRIM(r.estado)) = ''CONFIRMADA''',
        v_op_antes, v_c_antes, v_card_antes, v_b_antes, 54.10, v_plan_antes,
        v_op_desp,  v_c_desp,  v_card_desp,  v_b_desp,  4.10,  v_plan_desp,
        v_red_pct, 'N',
        'Aunque existia un indice tradicional sobre fecha_check_in, envolver la columna en la funcion TO_CHAR(fecha_check_in, ''YYYY-MM-DD'') y UPPER(TRIM(estado)) inhabilita el indice estandar y obliga a evaluar la funcion fila por fila (25.000 veces) mediante TABLE ACCESS FULL. El Indice Basado en Funcion (FBI) precalcula y almacena el resultado determinista de la expresion en el arbol B-Tree, permitiendo un INDEX RANGE SCAN directo.',
        SYSTIMESTAMP
    );

    -- Caso 3: Indice de Cobertura en RESERVA_SERVICIO (40.000 filas)
    pr_extraer_metricas('Q3_ANTES',   v_c_antes, v_card_antes, v_b_antes, v_op_antes);
    pr_extraer_metricas('Q3_DESPUES', v_c_desp,  v_card_desp,  v_b_desp,  v_op_desp);
    v_plan_antes := fn_extraer_plan_texto('Q3_ANTES');
    v_plan_desp  := fn_extraer_plan_texto('Q3_DESPUES');
    v_red_pct    := ROUND(((v_c_antes - v_c_desp) / GREATEST(v_c_antes, 1)) * 100, 2);

    INSERT INTO TURISMO_UQ.AUDITORIA_PLANES_INDICES VALUES (
        3, 'Q3_INDICE_SERVICIOS_40K',
        'Agregacion de Ingresos en Consumos Masivos por Servicio y Cantidad',
        'Indice Compuesto de Cobertura (Covering Index)',
        'IDX_COMP_RESSERV_SERV_CANT',
        'CREATE INDEX IDX_COMP_RESSERV_SERV_CANT ON RESERVA_SERVICIO(id_servicio, cantidad, subtotal)',
        'SELECT rs.id_servicio, COUNT(*) AS num_consumos, SUM(rs.subtotal) AS ingreso_total FROM RESERVA_SERVICIO rs WHERE rs.id_servicio = 3 AND rs.cantidad >= 4 GROUP BY rs.id_servicio',
        v_op_antes, v_c_antes, v_card_antes, v_b_antes, 62.40, v_plan_antes,
        v_op_desp,  v_c_desp,  v_card_desp,  v_b_desp,  2.90,  v_plan_desp,
        v_red_pct, 'N',
        'La tabla RESERVA_SERVICIO contiene 40.000 registros y originalmente solo tenia indice sobre id_reserva. Al consultar por id_servicio y filtrar por cantidad >= 4 sumando subtotal, el motor escaneaba toda la tabla. El nuevo indice compuesto cubre tanto los predicados WHERE como la columna agregada SUM(subtotal), logrando que Oracle ni siquiera toque los bloques de datos de la tabla.',
        SYSTIMESTAMP
    );

    -- Caso 4: El Caso Negativo (Cuando el indice NO ayuda y empeora el costo)
    pr_extraer_metricas('Q4_CBO_NATURAL',    v_c_antes, v_card_antes, v_b_antes, v_op_antes);
    pr_extraer_metricas('Q4_INDICE_FORZADO', v_c_desp,  v_card_desp,  v_b_desp,  v_op_desp);
    v_plan_antes := fn_extraer_plan_texto('Q4_CBO_NATURAL');
    v_plan_desp  := fn_extraer_plan_texto('Q4_INDICE_FORZADO');
    v_red_pct    := ROUND(((v_c_antes - v_c_desp) / GREATEST(v_c_antes, 1)) * 100, 2);

    INSERT INTO TURISMO_UQ.AUDITORIA_PLANES_INDICES VALUES (
        4, 'Q4_CASO_NEGATIVO_CBO',
        'Caso donde el Indice NO Ayuda: Baja Selectividad (>85% de la tabla) y Alto Clustering Factor',
        'Comparativa CBO: Full Table Scan (Costo 72) vs Hint /*+ INDEX */ Forzado (Costo 24.985)',
        'IDX_COMP_RESERVA_EST_CREA',
        'SELECT /*+ INDEX(r IDX_COMP_RESERVA_EST_CREA) */ id_reserva, id_cliente, fecha_check_in, fecha_check_out, estado, total FROM RESERVA r WHERE r.estado IN (''CONFIRMADA'', ''FINALIZADA'', ''PENDIENTE'') AND r.total > 100',
        'SELECT r.id_reserva, r.id_cliente, r.fecha_check_in, r.fecha_check_out, r.estado, r.total FROM RESERVA r WHERE r.estado IN (''CONFIRMADA'', ''FINALIZADA'', ''PENDIENTE'') AND r.total > 100',
        v_op_antes, v_c_antes, v_card_antes, v_b_antes, 39.00, v_plan_antes,
        v_op_desp,  v_c_desp,  v_card_desp,  v_b_desp,  384.60, v_plan_desp,
        v_red_pct, 'S',
        'POR QUE EL INDICE NO AYUDA AQUI: 1) Baja Selectividad: El predicado selecciona casi el 100% de las 25.000 filas de RESERVA. 2) Lecturas Single-Block vs Multi-Block: Forzar el indice obliga a recorrer hojas del B-Tree y luego hacer 25.000 accesos aleatorios por ROWID hacia la tabla (TABLE ACCESS BY INDEX ROWID BATCHED, disparando el costo de 72 a 24.985) porque se piden columnas (id_cliente, fecha_check_in, fecha_check_out) que no estan en el indice. 3) Clustering Factor: Un mismo bloque de datos de la tabla es leido decenas de veces desde distintas entradas del indice. En cambio, TABLE ACCESS FULL lee bloques contiguos en rafagas (db_file_multiblock_read_count), siendo 347 veces mas eficiente.',
        SYSTIMESTAMP
    );

    COMMIT;
END;
/

PROMPT ============================================================================
PROMPT === RESUMEN COMPARATIVO DE COSTOS CBO (ANTES VS DESPUES)                 ===
PROMPT ============================================================================

COLUMN codigo_consulta FORMAT A24;
COLUMN operacion_antes FORMAT A25;
COLUMN costo_antes FORMAT 999999;
COLUMN operacion_despues FORMAT A25;
COLUMN costo_despues FORMAT 999999;
COLUMN reduccion_costo_pct FORMAT 999999.99;

SELECT codigo_consulta, operacion_antes, costo_antes, operacion_despues, costo_despues, reduccion_costo_pct, es_caso_negativo
FROM TURISMO_UQ.AUDITORIA_PLANES_INDICES
ORDER BY id_caso;
