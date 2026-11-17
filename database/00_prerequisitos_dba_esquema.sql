-- ============================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- PREREQUISITOS DBA: CREACION IDEMPOTENTE DEL ESQUEMA BASE TURISMO_UQ
-- ARCHIVO: database/00_prerequisitos_dba_esquema.sql
-- MOTOR: ORACLE DATABASE 21c EXPRESS EDITION (PDB: XEPDB1)
-- NOTA: Ejecutar conectado como SYS AS SYSDBA (o usuario DBA administrador)
-- ============================================================================

ALTER SESSION SET CONTAINER = XEPDB1;

DECLARE
    v_existe NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_existe
    FROM dba_users
    WHERE username = 'TURISMO_UQ';

    IF v_existe = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE USER TURISMO_UQ IDENTIFIED BY "TurismoUQ2026#"
            DEFAULT TABLESPACE USERS
            TEMPORARY TABLESPACE TEMP
            QUOTA UNLIMITED ON USERS
            ACCOUNT UNLOCK
        ';
        DBMS_OUTPUT.PUT_LINE('Esquema TURISMO_UQ creado exitosamente.');
    ELSE
        EXECUTE IMMEDIATE 'ALTER USER TURISMO_UQ QUOTA UNLIMITED ON USERS ACCOUNT UNLOCK';
        DBMS_OUTPUT.PUT_LINE('Esquema TURISMO_UQ ya existente (cuota y estado verificados).');
    END IF;

    -- Privilegios base de desarrollo sobre su esquema
    EXECUTE IMMEDIATE 'GRANT CONNECT, RESOURCE TO TURISMO_UQ';
    EXECUTE IMMEDIATE 'GRANT CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER, CREATE MATERIALIZED VIEW TO TURISMO_UQ';
END;
/

PROMPT Prerrequisitos DBA y usuario TURISMO_UQ verificados en XEPDB1.
