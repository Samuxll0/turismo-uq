-- ========================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- ENTREGA 2: AJUSTE DE TEMPORADAS, PERIODOS DE TEMPORADA ALTA Y TARIFAS
-- ARCHIVO: 01_ajuste_temporadas_tarifas.sql
-- ========================================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = TURISMO_UQ;

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- 1. Creacion de la tabla PERIODO_TEMPORADA para detallar ventanas de Temporada Alta
BEGIN
    EXECUTE IMMEDIATE '
        CREATE TABLE TURISMO_UQ.PERIODO_TEMPORADA (
            id_periodo     NUMBER GENERATED ALWAYS AS IDENTITY,
            id_temporada   NUMBER NOT NULL,
            nombre         VARCHAR2(80) NOT NULL,
            fecha_inicio   DATE NOT NULL,
            fecha_fin      DATE NOT NULL,
            CONSTRAINT pk_periodo_temporada PRIMARY KEY (id_periodo),
            CONSTRAINT fk_periodo_temporada FOREIGN KEY (id_temporada) 
                REFERENCES TURISMO_UQ.TEMPORADA(id_temporada),
            CONSTRAINT chk_periodo_fechas CHECK (fecha_fin >= fecha_inicio)
        )';
    DBMS_OUTPUT.PUT_LINE('Tabla PERIODO_TEMPORADA creada exitosamente.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -955 THEN
            DBMS_OUTPUT.PUT_LINE('Tabla PERIODO_TEMPORADA ya existe.');
        ELSE
            RAISE;
        END IF;
END;
/

-- Indice optimizador para evaluacion de rangos temporales en fn_valor_estadia
BEGIN
    EXECUTE IMMEDIATE '
        CREATE INDEX TURISMO_UQ.idx_periodo_temp_fechas 
        ON TURISMO_UQ.PERIODO_TEMPORADA (id_temporada, fecha_inicio, fecha_fin)';
    DBMS_OUTPUT.PUT_LINE('Indice idx_periodo_temp_fechas creado.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -955 OR SQLCODE = -1408 THEN
            DBMS_OUTPUT.PUT_LINE('Indice idx_periodo_temp_fechas ya existe.');
        ELSE
            RAISE;
        END IF;
END;
/

-- 2. Creacion de la tabla LIQUIDACION_MENSUAL_HISTORICO para persistir corridas mensuales
BEGIN
    EXECUTE IMMEDIATE '
        CREATE TABLE TURISMO_UQ.LIQUIDACION_MENSUAL_HISTORICO (
            id_liquidacion    NUMBER GENERATED ALWAYS AS IDENTITY,
            anio              NUMBER(4) NOT NULL,
            mes               NUMBER(2) NOT NULL,
            id_alojamiento    NUMBER NOT NULL,
            total_reservas    NUMBER(10) DEFAULT 0 NOT NULL,
            total_hospedaje   NUMBER(14,2) DEFAULT 0 NOT NULL,
            total_servicios   NUMBER(14,2) DEFAULT 0 NOT NULL,
            total_ingresos    NUMBER(14,2) DEFAULT 0 NOT NULL,
            fecha_liquidacion DATE DEFAULT SYSDATE NOT NULL,
            CONSTRAINT pk_liq_mensual_hist PRIMARY KEY (id_liquidacion),
            CONSTRAINT fk_liq_hist_alojamiento FOREIGN KEY (id_alojamiento) 
                REFERENCES TURISMO_UQ.ALOJAMIENTO(id_alojamiento),
            CONSTRAINT uk_liq_hist_periodo UNIQUE (anio, mes, id_alojamiento),
            CONSTRAINT chk_liq_mes CHECK (mes BETWEEN 1 AND 12)
        ) TABLESPACE TBS_HISTORICO_RESERVAS';
    DBMS_OUTPUT.PUT_LINE('Tabla LIQUIDACION_MENSUAL_HISTORICO creada exitosamente.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -955 THEN
            DBMS_OUTPUT.PUT_LINE('Tabla LIQUIDACION_MENSUAL_HISTORICO ya existe.');
        ELSE
            RAISE;
        END IF;
END;
/

-- 3. Reestructuracion de TEMPORADA, PERIODOS y recalculo de TARIFAS
DECLARE
    TYPE t_tarifa_base_rec IS RECORD (
        id_habitacion NUMBER,
        precio_base   NUMBER(12,2)
    );
    TYPE t_tarifa_base_tab IS TABLE OF t_tarifa_base_rec;
    v_tarifas_base t_tarifa_base_tab := t_tarifa_base_tab();
    v_num_temporadas NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_num_temporadas FROM TURISMO_UQ.TEMPORADA;

    -- Si existen mas de 2 temporadas, calcular precio promedio base redondeado a miles
    IF v_num_temporadas > 2 THEN
        SELECT id_habitacion, ROUND(AVG(precio_noche), -3)
        BULK COLLECT INTO v_tarifas_base
        FROM TURISMO_UQ.TARIFA
        GROUP BY id_habitacion;
    ELSE
        -- Si ya fue reestructurada, tomar el precio base de la temporada 1 (baja)
        SELECT id_habitacion, precio_noche
        BULK COLLECT INTO v_tarifas_base
        FROM TURISMO_UQ.TARIFA
        WHERE id_temporada = 1;
    END IF;

    -- 3.1 Limpiar tarifas existentes para redefinir el esquema de dos temporadas
    DELETE FROM TURISMO_UQ.TARIFA;
    DBMS_OUTPUT.PUT_LINE('Registros anteriores de TARIFA eliminados.');

    -- 3.2 Limpiar y redefinir PERIODOS de temporada alta
    DELETE FROM TURISMO_UQ.PERIODO_TEMPORADA;

    -- 3.3 Reestructurar TEMPORADA: ID 1 = Temporada Baja, ID 2 = Temporada Alta
    DELETE FROM TURISMO_UQ.TEMPORADA WHERE id_temporada > 2;

    UPDATE TURISMO_UQ.TEMPORADA
    SET nombre = 'Temporada Baja',
        fecha_inicio = DATE '2024-01-01',
        fecha_fin = DATE '2026-12-31'
    WHERE id_temporada = 1;

    UPDATE TURISMO_UQ.TEMPORADA
    SET nombre = 'Temporada Alta',
        fecha_inicio = DATE '2024-01-01',
        fecha_fin = DATE '2026-12-31'
    WHERE id_temporada = 2;

    DBMS_OUTPUT.PUT_LINE('TEMPORADA reestructurada con IDs 1 y 2 (2024-01-01 a 2026-12-31).');

    -- 3.4 Poblacion de ventanas de Temporada Alta en PERIODO_TEMPORADA (2024, 2025, 2026)
    -- 2024
    INSERT INTO TURISMO_UQ.PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
    VALUES (2, 'Semana Santa 2024', DATE '2024-03-23', DATE '2024-03-31');

    INSERT INTO TURISMO_UQ.PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
    VALUES (2, 'Mitad de Anio 2024', DATE '2024-06-15', DATE '2024-07-20');

    INSERT INTO TURISMO_UQ.PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
    VALUES (2, 'Fin de Anio 2024', DATE '2024-12-15', DATE '2025-01-15');

    -- 2025
    INSERT INTO TURISMO_UQ.PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
    VALUES (2, 'Semana Santa 2025', DATE '2025-04-12', DATE '2025-04-20');

    INSERT INTO TURISMO_UQ.PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
    VALUES (2, 'Mitad de Anio 2025', DATE '2025-06-14', DATE '2025-07-19');

    INSERT INTO TURISMO_UQ.PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
    VALUES (2, 'Fin de Anio 2025', DATE '2025-12-15', DATE '2026-01-15');

    -- 2026
    INSERT INTO TURISMO_UQ.PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
    VALUES (2, 'Semana Santa 2026', DATE '2026-03-28', DATE '2026-04-05');

    INSERT INTO TURISMO_UQ.PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
    VALUES (2, 'Mitad de Anio 2026', DATE '2026-06-15', DATE '2026-07-20');

    INSERT INTO TURISMO_UQ.PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
    VALUES (2, 'Fin de Anio 2026', DATE '2026-12-15', DATE '2027-01-15');

    DBMS_OUTPUT.PUT_LINE('9 Periodos de Temporada Alta registrados en PERIODO_TEMPORADA.');

    -- 3.5 Insercion masiva en TARIFA: exactamente 2 tarifas por habitacion (800 filas)
    FOR i IN 1..v_tarifas_base.COUNT LOOP
        -- Tarifa Temporada Baja (ID_TEMPORADA = 1): Precio base promedio redondeado a miles
        INSERT INTO TURISMO_UQ.TARIFA (precio_noche, id_temporada, id_habitacion)
        VALUES (v_tarifas_base(i).precio_base, 1, v_tarifas_base(i).id_habitacion);

        -- Tarifa Temporada Alta (ID_TEMPORADA = 2): Incremento exacto del 40%
        INSERT INTO TURISMO_UQ.TARIFA (precio_noche, id_temporada, id_habitacion)
        VALUES (ROUND(v_tarifas_base(i).precio_base * 1.40), 2, v_tarifas_base(i).id_habitacion);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('800 tarifas insertadas exitosamente (400 baja + 400 alta).');
    COMMIT;
END;
/

-- 4. Verificacion de consistencia y conteos
PROMPT ========================================================================
PROMPT VERIFICACION POST-EJECUCION: 01_ajuste_temporadas_tarifas.sql
PROMPT ========================================================================

SELECT id_temporada, nombre, TO_CHAR(fecha_inicio, 'YYYY-MM-DD') AS inicio, TO_CHAR(fecha_fin, 'YYYY-MM-DD') AS fin
FROM TURISMO_UQ.TEMPORADA
ORDER BY id_temporada;

SELECT id_periodo, id_temporada, nombre, TO_CHAR(fecha_inicio, 'YYYY-MM-DD') AS inicio, TO_CHAR(fecha_fin, 'YYYY-MM-DD') AS fin
FROM TURISMO_UQ.PERIODO_TEMPORADA
ORDER BY fecha_inicio;

SELECT id_temporada, COUNT(*) AS total_habitaciones, MIN(precio_noche) AS min_precio, MAX(precio_noche) AS max_precio, ROUND(AVG(precio_noche), 2) AS avg_precio
FROM TURISMO_UQ.TARIFA
GROUP BY id_temporada
ORDER BY id_temporada;

SELECT COUNT(*) AS total_tarifas_global FROM TURISMO_UQ.TARIFA;
