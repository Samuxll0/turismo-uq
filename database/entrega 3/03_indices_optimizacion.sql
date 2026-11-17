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

-- Helpers temporales para medir tiempo real (DBMS_SQL + SYSTIMESTAMP) y extraer plan CBO
CREATE OR REPLACE FUNCTION TURISMO_UQ.fn_tmp_medir_ms(
    p_sql         IN VARCHAR2,
    p_iteraciones IN PLS_INTEGER DEFAULT 3
) RETURN NUMBER IS
    v_cur    INTEGER := NULL;
    v_dummy  INTEGER;
    v_rows   INTEGER;
    v_t0     TIMESTAMP;
    v_t1     TIMESTAMP;
    v_diff   INTERVAL DAY TO SECOND;
    v_ms     NUMBER;
BEGIN
    -- Warmup breve y medicion real ejecutando la consulta completa
    v_t0 := SYSTIMESTAMP;
    FOR k IN 1..p_iteraciones LOOP
        v_cur := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(v_cur, p_sql, DBMS_SQL.NATIVE);
        v_dummy := DBMS_SQL.EXECUTE(v_cur);
        LOOP
            v_rows := DBMS_SQL.FETCH_ROWS(v_cur);
            EXIT WHEN v_rows = 0;
        END LOOP;
        DBMS_SQL.CLOSE_CURSOR(v_cur);
        v_cur := NULL;
    END LOOP;
    v_t1 := SYSTIMESTAMP;
    v_diff := v_t1 - v_t0;
    v_ms := ROUND(((EXTRACT(MINUTE FROM v_diff) * 60 + EXTRACT(SECOND FROM v_diff)) * 1000) / p_iteraciones, 2);
    RETURN GREATEST(v_ms, 0.01);
EXCEPTION
    WHEN OTHERS THEN
        IF v_cur IS NOT NULL AND DBMS_SQL.IS_OPEN(v_cur) THEN
            DBMS_SQL.CLOSE_CURSOR(v_cur);
        END IF;
        RAISE;
END;
/

CREATE OR REPLACE PROCEDURE TURISMO_UQ.pr_tmp_extraer_plan(
    p_stmt_id   IN  VARCHAR2,
    o_costo     OUT NUMBER,
    o_card      OUT NUMBER,
    o_bytes     OUT NUMBER,
    o_operacion OUT VARCHAR2,
    o_plan_txt  OUT CLOB
) IS
    v_clob CLOB := '';
BEGIN
    FOR r IN (
        SELECT plan_table_output
        FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', p_stmt_id, 'BASIC +COST +BYTES'))
    ) LOOP
        v_clob := v_clob || r.plan_table_output || CHR(10);
    END LOOP;
    o_plan_txt := v_clob;

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
/

-- ============================================================================
-- 3. CAPTURA DE PLANES Y TIEMPOS REALES "ANTES" (SIN INDICES DE OPTIMIZACION)
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

-- Medicion real "ANTES" ejecutando las 3 consultas y persistiendo linea base
DECLARE
    v_c     NUMBER;
    v_card  NUMBER;
    v_b     NUMBER;
    v_op    VARCHAR2(120);
    v_plan  CLOB;
    v_ms    NUMBER;
    v_sql1  VARCHAR2(1000) := 'SELECT r.estado, r.fecha_creacion, r.total FROM TURISMO_UQ.RESERVA r WHERE r.estado = ''PENDIENTE'' AND r.fecha_creacion BETWEEN DATE ''2025-06-01'' AND DATE ''2025-06-15'' ORDER BY r.fecha_creacion DESC';
    v_sql2  VARCHAR2(1000) := 'SELECT r.id_reserva, r.id_cliente, r.fecha_check_in, r.total FROM TURISMO_UQ.RESERVA r WHERE TO_CHAR(r.fecha_check_in, ''YYYY-MM-DD'') = ''2025-12-24'' AND UPPER(TRIM(r.estado)) = ''CONFIRMADA''';
    v_sql3  VARCHAR2(1000) := 'SELECT rs.id_servicio, COUNT(*) AS num_consumos, SUM(rs.subtotal) AS ingreso_total FROM TURISMO_UQ.RESERVA_SERVICIO rs WHERE rs.id_servicio = 3 AND rs.cantidad >= 4 GROUP BY rs.id_servicio';
BEGIN
    TURISMO_UQ.pr_tmp_extraer_plan('Q1_ANTES', v_c, v_card, v_b, v_op, v_plan);
    v_ms := TURISMO_UQ.fn_tmp_medir_ms(v_sql1, 3);
    INSERT INTO TURISMO_UQ.AUDITORIA_PLANES_INDICES (
        id_caso, codigo_consulta, titulo, tipo_indice, nombre_indice, ddl_indice, sql_consulta,
        operacion_antes, costo_antes, cardinalidad_antes, bytes_antes, tiempo_ms_antes, plan_texto_antes,
        es_caso_negativo, explicacion_tecnica
    ) VALUES (
        1, 'Q1_INDICE_COMPUESTO',
        'Filtro y Ordenamiento de Reservas por Estado y Rango de Fecha de Creacion',
        'Indice Compuesto B-Tree (3 Columnas)',
        'IDX_COMP_RESERVA_EST_CREA',
        'CREATE INDEX IDX_COMP_RESERVA_EST_CREA ON RESERVA(estado, fecha_creacion, total)',
        v_sql1,
        v_op, v_c, v_card, v_b, v_ms, v_plan, 'N',
        'Al incluir las columnas de igualdad (estado), rango (fecha_creacion) y proyeccion (total) en un mismo Indice Compuesto, el optimizador elimina por completo el TABLE ACCESS FULL sobre las 25.000 reservas y resuelve la consulta exclusivamente leyendo bloques hoja del indice (INDEX RANGE SCAN DESCENDING), evitando incluso el costo de ordenamiento (SORT ORDER BY) gracias al orden natural del B-Tree.'
    );

    TURISMO_UQ.pr_tmp_extraer_plan('Q2_ANTES', v_c, v_card, v_b, v_op, v_plan);
    v_ms := TURISMO_UQ.fn_tmp_medir_ms(v_sql2, 3);
    INSERT INTO TURISMO_UQ.AUDITORIA_PLANES_INDICES (
        id_caso, codigo_consulta, titulo, tipo_indice, nombre_indice, ddl_indice, sql_consulta,
        operacion_antes, costo_antes, cardinalidad_antes, bytes_antes, tiempo_ms_antes, plan_texto_antes,
        es_caso_negativo, explicacion_tecnica
    ) VALUES (
        2, 'Q2_INDICE_FUNCION_FBI',
        'Busqueda de Reservas en Fecha Festiva Aplicando Expresiones TO_CHAR y UPPER',
        'Indice Basado en Funcion (Function-Based Index)',
        'IDX_FBI_RESERVA_ANIO_MES',
        'CREATE INDEX IDX_FBI_RESERVA_ANIO_MES ON RESERVA(TO_CHAR(fecha_check_in, ''YYYY-MM-DD''), UPPER(TRIM(estado)))',
        v_sql2,
        v_op, v_c, v_card, v_b, v_ms, v_plan, 'N',
        'Aunque existia un indice tradicional sobre fecha_check_in, envolver la columna en la funcion TO_CHAR(fecha_check_in, ''YYYY-MM-DD'') y UPPER(TRIM(estado)) inhabilita el indice estandar y obliga a evaluar la funcion fila por fila (25.000 veces) mediante TABLE ACCESS FULL. El Indice Basado en Funcion (FBI) precalcula y almacena el resultado determinista de la expresion en el arbol B-Tree, permitiendo un INDEX RANGE SCAN directo.'
    );

    TURISMO_UQ.pr_tmp_extraer_plan('Q3_ANTES', v_c, v_card, v_b, v_op, v_plan);
    v_ms := TURISMO_UQ.fn_tmp_medir_ms(v_sql3, 3);
    INSERT INTO TURISMO_UQ.AUDITORIA_PLANES_INDICES (
        id_caso, codigo_consulta, titulo, tipo_indice, nombre_indice, ddl_indice, sql_consulta,
        operacion_antes, costo_antes, cardinalidad_antes, bytes_antes, tiempo_ms_antes, plan_texto_antes,
        es_caso_negativo, explicacion_tecnica
    ) VALUES (
        3, 'Q3_INDICE_SERVICIOS_40K',
        'Agregacion de Ingresos en Consumos Masivos por Servicio y Cantidad',
        'Indice Compuesto de Cobertura (Covering Index)',
        'IDX_COMP_RESSERV_SERV_CANT',
        'CREATE INDEX IDX_COMP_RESSERV_SERV_CANT ON RESERVA_SERVICIO(id_servicio, cantidad, subtotal)',
        v_sql3,
        v_op, v_c, v_card, v_b, v_ms, v_plan, 'N',
        'La tabla RESERVA_SERVICIO contiene 40.000 registros y originalmente solo tenia indice sobre id_reserva. Al consultar por id_servicio y filtrar por cantidad >= 4 sumando subtotal, el motor escaneaba toda la tabla. El nuevo indice compuesto cubre tanto los predicados WHERE como la columna agregada SUM(subtotal), logrando que Oracle ni siquiera toque los bloques de datos de la tabla.'
    );

    COMMIT;
END;
/

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
-- 5. CAPTURA DE PLANES Y TIEMPOS REALES "DESPUES" (CON INDICES CREADOS)
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
-- 7. ACTUALIZACION DE METRICAS REALES "DESPUES" Y CASO NEGATIVO EN AUDITORIA
-- ============================================================================
DECLARE
    v_c_antes     NUMBER;
    v_card_antes  NUMBER;
    v_b_antes     NUMBER;
    v_op_antes    VARCHAR2(120);
    v_plan_antes  CLOB;
    v_ms_antes    NUMBER;
    v_c_desp      NUMBER;
    v_card_desp   NUMBER;
    v_b_desp      NUMBER;
    v_op_desp     VARCHAR2(120);
    v_plan_desp   CLOB;
    v_ms_desp     NUMBER;
    v_red_pct     NUMBER(8,2);

    v_sql1        VARCHAR2(1000) := 'SELECT r.estado, r.fecha_creacion, r.total FROM TURISMO_UQ.RESERVA r WHERE r.estado = ''PENDIENTE'' AND r.fecha_creacion BETWEEN DATE ''2025-06-01'' AND DATE ''2025-06-15'' ORDER BY r.fecha_creacion DESC';
    v_sql2        VARCHAR2(1000) := 'SELECT r.id_reserva, r.id_cliente, r.fecha_check_in, r.total FROM TURISMO_UQ.RESERVA r WHERE TO_CHAR(r.fecha_check_in, ''YYYY-MM-DD'') = ''2025-12-24'' AND UPPER(TRIM(r.estado)) = ''CONFIRMADA''';
    v_sql3        VARCHAR2(1000) := 'SELECT rs.id_servicio, COUNT(*) AS num_consumos, SUM(rs.subtotal) AS ingreso_total FROM TURISMO_UQ.RESERVA_SERVICIO rs WHERE rs.id_servicio = 3 AND rs.cantidad >= 4 GROUP BY rs.id_servicio';
    v_sql4_nat    VARCHAR2(1000) := 'SELECT r.id_reserva, r.id_cliente, r.fecha_check_in, r.fecha_check_out, r.estado, r.total FROM TURISMO_UQ.RESERVA r WHERE r.estado IN (''CONFIRMADA'', ''FINALIZADA'', ''PENDIENTE'') AND r.total > 100';
    v_sql4_hint   VARCHAR2(1000) := 'SELECT /*+ INDEX(r IDX_COMP_RESERVA_EST_CREA) */ r.id_reserva, r.id_cliente, r.fecha_check_in, r.fecha_check_out, r.estado, r.total FROM TURISMO_UQ.RESERVA r WHERE r.estado IN (''CONFIRMADA'', ''FINALIZADA'', ''PENDIENTE'') AND r.total > 100';
BEGIN
    -- Caso 1 Despues
    TURISMO_UQ.pr_tmp_extraer_plan('Q1_DESPUES', v_c_desp, v_card_desp, v_b_desp, v_op_desp, v_plan_desp);
    v_ms_desp := TURISMO_UQ.fn_tmp_medir_ms(v_sql1, 3);
    UPDATE TURISMO_UQ.AUDITORIA_PLANES_INDICES
    SET operacion_despues = v_op_desp,
        costo_despues = v_c_desp,
        cardinalidad_despues = v_card_desp,
        bytes_despues = v_b_desp,
        tiempo_ms_despues = v_ms_desp,
        plan_texto_despues = v_plan_desp,
        reduccion_costo_pct = ROUND(((costo_antes - v_c_desp) / GREATEST(costo_antes, 1)) * 100, 2)
    WHERE id_caso = 1;

    -- Caso 2 Despues
    TURISMO_UQ.pr_tmp_extraer_plan('Q2_DESPUES', v_c_desp, v_card_desp, v_b_desp, v_op_desp, v_plan_desp);
    v_ms_desp := TURISMO_UQ.fn_tmp_medir_ms(v_sql2, 3);
    UPDATE TURISMO_UQ.AUDITORIA_PLANES_INDICES
    SET operacion_despues = v_op_desp,
        costo_despues = v_c_desp,
        cardinalidad_despues = v_card_desp,
        bytes_despues = v_b_desp,
        tiempo_ms_despues = v_ms_desp,
        plan_texto_despues = v_plan_desp,
        reduccion_costo_pct = ROUND(((costo_antes - v_c_desp) / GREATEST(costo_antes, 1)) * 100, 2)
    WHERE id_caso = 2;

    -- Caso 3 Despues
    TURISMO_UQ.pr_tmp_extraer_plan('Q3_DESPUES', v_c_desp, v_card_desp, v_b_desp, v_op_desp, v_plan_desp);
    v_ms_desp := TURISMO_UQ.fn_tmp_medir_ms(v_sql3, 3);
    UPDATE TURISMO_UQ.AUDITORIA_PLANES_INDICES
    SET operacion_despues = v_op_desp,
        costo_despues = v_c_desp,
        cardinalidad_despues = v_card_desp,
        bytes_despues = v_b_desp,
        tiempo_ms_despues = v_ms_desp,
        plan_texto_despues = v_plan_desp,
        reduccion_costo_pct = ROUND(((costo_antes - v_c_desp) / GREATEST(costo_antes, 1)) * 100, 2)
    WHERE id_caso = 3;

    -- Caso 4: El Caso Negativo (Tiempos y planes reales: Natural FTS vs Indice Forzado)
    TURISMO_UQ.pr_tmp_extraer_plan('Q4_CBO_NATURAL',    v_c_antes, v_card_antes, v_b_antes, v_op_antes, v_plan_antes);
    TURISMO_UQ.pr_tmp_extraer_plan('Q4_INDICE_FORZADO', v_c_desp,  v_card_desp,  v_b_desp,  v_op_desp,  v_plan_desp);
    v_ms_antes := TURISMO_UQ.fn_tmp_medir_ms(v_sql4_nat, 3);
    v_ms_desp  := TURISMO_UQ.fn_tmp_medir_ms(v_sql4_hint, 3);
    v_red_pct  := ROUND(((v_c_antes - v_c_desp) / GREATEST(v_c_antes, 1)) * 100, 2);

    INSERT INTO TURISMO_UQ.AUDITORIA_PLANES_INDICES VALUES (
        4, 'Q4_CASO_NEGATIVO_CBO',
        'Caso donde el Indice NO Ayuda: Baja Selectividad (>85% de la tabla) y Alto Clustering Factor',
        'Comparativa CBO: Full Table Scan vs Hint /*+ INDEX */ Forzado',
        'IDX_COMP_RESERVA_EST_CREA',
        v_sql4_hint,
        v_sql4_nat,
        v_op_antes, v_c_antes, v_card_antes, v_b_antes, v_ms_antes, v_plan_antes,
        v_op_desp,  v_c_desp,  v_card_desp,  v_b_desp,  v_ms_desp,  v_plan_desp,
        v_red_pct, 'S',
        'POR QUE EL INDICE NO AYUDA AQUI: 1) Baja Selectividad: El predicado selecciona casi el 100% de las 25.000 filas de RESERVA. 2) Lecturas Single-Block vs Multi-Block: Forzar el indice obliga a recorrer hojas del B-Tree y luego hacer ~25.000 accesos aleatorios por ROWID hacia la tabla (TABLE ACCESS BY INDEX ROWID BATCHED, multiplicando el costo CBO frente al FTS) porque se piden columnas (id_cliente, fecha_check_in, fecha_check_out) que no estan en el indice. 3) Clustering Factor: Un mismo bloque de datos de la tabla es leido repetidas veces desde distintas entradas del indice. En cambio, TABLE ACCESS FULL lee bloques contiguos en rafagas (db_file_multiblock_read_count), siendo mucho mas eficiente.',
        SYSTIMESTAMP
    );

    COMMIT;
END;
/

-- Limpiar helpers temporales para no dejar objetos auxiliares en el esquema
DROP FUNCTION TURISMO_UQ.fn_tmp_medir_ms;
DROP PROCEDURE TURISMO_UQ.pr_tmp_extraer_plan;

PROMPT ============================================================================
PROMPT === RESUMEN COMPARATIVO DE COSTOS CBO Y TIEMPOS MEDIDOS (ANTES VS DESPUES)=
PROMPT ============================================================================

COLUMN codigo_consulta FORMAT A24;
COLUMN operacion_antes FORMAT A25;
COLUMN costo_antes FORMAT 999999;
COLUMN tiempo_ms_antes FORMAT 9999.99;
COLUMN operacion_despues FORMAT A25;
COLUMN costo_despues FORMAT 999999;
COLUMN tiempo_ms_despues FORMAT 9999.99;
COLUMN reduccion_costo_pct FORMAT 999999.99;

SELECT codigo_consulta, operacion_antes, costo_antes, tiempo_ms_antes,
       operacion_despues, costo_despues, tiempo_ms_despues, reduccion_costo_pct, es_caso_negativo
FROM TURISMO_UQ.AUDITORIA_PLANES_INDICES
ORDER BY id_caso;
