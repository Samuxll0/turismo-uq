-- ========================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- ENTREGA 1: CONFIGURACION DE TABLESPACE HISTORICO DE RESERVAS
-- ========================================================================

ALTER SESSION SET CONTAINER = XEPDB1;

-- 1. Creacion del Tablespace permanente para historico de reservas
-- Aislamiento de I/O, retencion y gestion diferenciada de almacenamiento
CREATE TABLESPACE TBS_HISTORICO_RESERVAS
    DATAFILE 'C:\APP\SAMUEL\PRODUCT\21C\ORADATA\XE\XEPDB1\TBS_HIST_RESERVAS01.DBF'
    SIZE 100M
    AUTOEXTEND ON NEXT 50M
    MAXSIZE 2048M
    EXTENT MANAGEMENT LOCAL
    SEGMENT SPACE MANAGEMENT AUTO;

-- 2. Asignacion de cuota ilimitada al usuario del esquema
ALTER USER TURISMO_UQ QUOTA UNLIMITED ON TBS_HISTORICO_RESERVAS;

-- 3. Reubicacion fisica de las tablas de alto volumen y crecimiento transaccional
ALTER TABLE TURISMO_UQ.RESERVA MOVE TABLESPACE TBS_HISTORICO_RESERVAS;
ALTER TABLE TURISMO_UQ.RESERVA_HABITACION MOVE TABLESPACE TBS_HISTORICO_RESERVAS;
ALTER TABLE TURISMO_UQ.RESERVA_SERVICIO MOVE TABLESPACE TBS_HISTORICO_RESERVAS;
ALTER TABLE TURISMO_UQ.PAGO MOVE TABLESPACE TBS_HISTORICO_RESERVAS;

-- 4. Reconstruccion automatica de indices invalidos tras la reubicacion
BEGIN
    FOR idx IN (
        SELECT owner, index_name 
        FROM dba_indexes 
        WHERE owner = 'TURISMO_UQ' 
          AND status = 'UNUSABLE'
    ) LOOP
        EXECUTE IMMEDIATE 'ALTER INDEX ' || idx.owner || '.' || idx.index_name || ' REBUILD TABLESPACE TBS_HISTORICO_RESERVAS';
    END LOOP;
END;
/

-- 5. Verificacion del estado de las tablas y del tablespace
SELECT table_name, tablespace_name 
FROM dba_tables 
WHERE owner = 'TURISMO_UQ' AND tablespace_name = 'TBS_HISTORICO_RESERVAS'
ORDER BY table_name;

SELECT index_name, status, tablespace_name
FROM dba_indexes
WHERE owner = 'TURISMO_UQ' AND table_name IN ('RESERVA', 'RESERVA_HABITACION', 'RESERVA_SERVICIO', 'PAGO')
ORDER BY table_name, index_name;
