-- ============================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- ENTREGA 1: SCRIPT 03 - CONFIGURACION Y MIGRACION A TABLESPACE DEDICADO
-- TABLESPACE: TBS_HISTORICO_RESERVAS (Aislamiento de I/O y Politicas DBA)
-- MOTOR: ORACLE DATABASE 21c EXPRESS EDITION (PDB: XEPDB1)
-- ============================================================================

ALTER SESSION SET CONTAINER = XEPDB1;

-- 1. Creacion del Tablespace permanente para historico de reservas
-- Nota: Si OMF (db_create_file_dest) no esta activo, resuelve automaticamente
--       el directorio real de los datafiles desde dba_data_files (Windows/Linux).
DECLARE
    v_dir VARCHAR2(500);
BEGIN
    EXECUTE IMMEDIATE '
        CREATE TABLESPACE TBS_HISTORICO_RESERVAS
            DATAFILE ''tbs_historico_reservas01.dbf''
            SIZE 100M
            AUTOEXTEND ON NEXT 50M
            MAXSIZE 2048M
            EXTENT MANAGEMENT LOCAL
            SEGMENT SPACE MANAGEMENT AUTO';
    DBMS_OUTPUT.PUT_LINE('Tablespace TBS_HISTORICO_RESERVAS creado exitosamente.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -959 OR SQLCODE = -1543 THEN
            DBMS_OUTPUT.PUT_LINE('Tablespace TBS_HISTORICO_RESERVAS ya existe.');
        ELSE
            BEGIN
                SELECT SUBSTR(file_name, 1, GREATEST(INSTR(file_name, '\', -1), INSTR(file_name, '/', -1)))
                INTO v_dir
                FROM dba_data_files
                WHERE ROWNUM = 1;

                EXECUTE IMMEDIATE '
                    CREATE TABLESPACE TBS_HISTORICO_RESERVAS
                        DATAFILE ''' || v_dir || 'tbs_hist_reservas01.dbf''
                        SIZE 100M
                        AUTOEXTEND ON NEXT 50M
                        MAXSIZE 2048M
                        EXTENT MANAGEMENT LOCAL
                        SEGMENT SPACE MANAGEMENT AUTO';
                DBMS_OUTPUT.PUT_LINE('Tablespace TBS_HISTORICO_RESERVAS creado en: ' || v_dir);
            EXCEPTION
                WHEN OTHERS THEN
                    IF SQLCODE = -959 OR SQLCODE = -1543 THEN
                        DBMS_OUTPUT.PUT_LINE('Tablespace TBS_HISTORICO_RESERVAS ya existe.');
                    ELSE
                        RAISE;
                    END IF;
            END;
        END IF;
END;
/

-- 2. Asignacion de cuota ilimitada al usuario del esquema
ALTER USER TURISMO_UQ QUOTA UNLIMITED ON TBS_HISTORICO_RESERVAS;

-- 3. Reubicacion fisica de las tablas de alto volumen y crecimiento transaccional
ALTER TABLE TURISMO_UQ.RESERVA MOVE TABLESPACE TBS_HISTORICO_RESERVAS;
ALTER TABLE TURISMO_UQ.RESERVA_HABITACION MOVE TABLESPACE TBS_HISTORICO_RESERVAS;
ALTER TABLE TURISMO_UQ.RESERVA_SERVICIO MOVE TABLESPACE TBS_HISTORICO_RESERVAS;
ALTER TABLE TURISMO_UQ.PAGO MOVE TABLESPACE TBS_HISTORICO_RESERVAS;
ALTER TABLE TURISMO_UQ.LIQUIDACION_MENSUAL_HISTORICO MOVE TABLESPACE TBS_HISTORICO_RESERVAS;

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
WHERE owner = 'TURISMO_UQ' AND table_name IN ('RESERVA', 'RESERVA_HABITACION', 'RESERVA_SERVICIO', 'PAGO', 'LIQUIDACION_MENSUAL_HISTORICO')
ORDER BY table_name, index_name;
