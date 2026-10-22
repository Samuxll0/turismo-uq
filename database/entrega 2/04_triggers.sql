-- ========================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- ENTREGA 2: TRIGGERS DE AUDITORIA Y CONTROL DE CONCURRENCIA
-- ARCHIVO: database/entrega 2/04_triggers.sql
-- ========================================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = TURISMO_UQ;

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- 1. Tabla de Auditoria de Tarifas Fila por Fila
BEGIN
    EXECUTE IMMEDIATE '
        CREATE TABLE TURISMO_UQ.AUDITORIA_TARIFA (
            id_auditoria    NUMBER GENERATED ALWAYS AS IDENTITY,
            usuario         VARCHAR2(60) NOT NULL,
            fecha           DATE DEFAULT SYSDATE NOT NULL,
            id_tarifa       NUMBER,
            id_habitacion   NUMBER,
            id_temporada    NUMBER,
            precio_anterior NUMBER(12,2),
            precio_nuevo    NUMBER(12,2),
            accion          VARCHAR2(10) NOT NULL,
            CONSTRAINT pk_auditoria_tarifa PRIMARY KEY (id_auditoria),
            CONSTRAINT chk_auditoria_accion CHECK (accion IN (''INSERT'', ''UPDATE'', ''DELETE''))
        )';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -955 THEN NULL; ELSE RAISE; END IF;
END;
/

-- 2. Tabla de Log a Nivel de Sentencia
BEGIN
    EXECUTE IMMEDIATE '
        CREATE TABLE TURISMO_UQ.LOG_SENTENCIA_TARIFA (
            id_log          NUMBER GENERATED ALWAYS AS IDENTITY,
            usuario         VARCHAR2(60) NOT NULL,
            fecha           DATE DEFAULT SYSDATE NOT NULL,
            accion          VARCHAR2(10) NOT NULL,
            total_filas     NUMBER NOT NULL,
            CONSTRAINT pk_log_sentencia_tarifa PRIMARY KEY (id_log),
            CONSTRAINT chk_log_accion CHECK (accion IN (''INSERT'', ''UPDATE'', ''DELETE''))
        )';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -955 THEN NULL; ELSE RAISE; END IF;
END;
/

-- 3. Disparador de Auditoria sobre TARIFA
-- Implementado como Compound Trigger para auditar tanto a nivel de fila (valores anterior y nuevo)
-- como a nivel de sentencia (registro consolidado por ejecucion DML)
CREATE OR REPLACE TRIGGER TURISMO_UQ.TRG_AUDITORIA_TARIFA
FOR INSERT OR UPDATE OR DELETE ON TURISMO_UQ.TARIFA
COMPOUND TRIGGER

    g_usuario        VARCHAR2(60);
    g_filas_afectadas NUMBER := 0;
    g_accion         VARCHAR2(10);

    BEFORE STATEMENT IS
    BEGIN
        g_usuario := SYS_CONTEXT('USERENV', 'SESSION_USER');
        g_filas_afectadas := 0;
        IF INSERTING THEN
            g_accion := 'INSERT';
        ELSIF UPDATING THEN
            g_accion := 'UPDATE';
        ELSIF DELETING THEN
            g_accion := 'DELETE';
        END IF;
    END BEFORE STATEMENT;

    AFTER EACH ROW IS
    BEGIN
        g_filas_afectadas := g_filas_afectadas + 1;

        IF INSERTING THEN
            INSERT INTO TURISMO_UQ.AUDITORIA_TARIFA (
                usuario, fecha, id_tarifa, id_habitacion, id_temporada,
                precio_anterior, precio_nuevo, accion
            ) VALUES (
                g_usuario, SYSDATE, :NEW.id_tarifa, :NEW.id_habitacion, :NEW.id_temporada,
                NULL, :NEW.precio_noche, 'INSERT'
            );
        ELSIF UPDATING THEN
            INSERT INTO TURISMO_UQ.AUDITORIA_TARIFA (
                usuario, fecha, id_tarifa, id_habitacion, id_temporada,
                precio_anterior, precio_nuevo, accion
            ) VALUES (
                g_usuario, SYSDATE, :OLD.id_tarifa, :OLD.id_habitacion, :OLD.id_temporada,
                :OLD.precio_noche, :NEW.precio_noche, 'UPDATE'
            );
        ELSIF DELETING THEN
            INSERT INTO TURISMO_UQ.AUDITORIA_TARIFA (
                usuario, fecha, id_tarifa, id_habitacion, id_temporada,
                precio_anterior, precio_nuevo, accion
            ) VALUES (
                g_usuario, SYSDATE, :OLD.id_tarifa, :OLD.id_habitacion, :OLD.id_temporada,
                :OLD.precio_noche, NULL, 'DELETE'
            );
        END IF;
    END AFTER EACH ROW;

    -- Auditoría a nivel de sentencia: persiste el evento consolidado del bloque DML
    AFTER STATEMENT IS
    BEGIN
        IF g_filas_afectadas > 0 THEN
            INSERT INTO TURISMO_UQ.LOG_SENTENCIA_TARIFA (
                usuario, fecha, accion, total_filas
            ) VALUES (
                g_usuario, SYSDATE, g_accion, g_filas_afectadas
            );
        END IF;
    END AFTER STATEMENT;

END TRG_AUDITORIA_TARIFA;
/

-- 4. Compound Trigger sobre RESERVA_HABITACION
-- Blindado contra el error mutante ORA-04091 mediante estructura compuesta
CREATE OR REPLACE TRIGGER TURISMO_UQ.TRG_PREVENIR_SOLAPAMIENTO_RESHAB
FOR INSERT OR UPDATE ON TURISMO_UQ.RESERVA_HABITACION
COMPOUND TRIGGER

    TYPE t_reshab_item IS RECORD (
        id_reserva    TURISMO_UQ.RESERVA_HABITACION.id_reserva%TYPE,
        id_habitacion TURISMO_UQ.RESERVA_HABITACION.id_habitacion%TYPE
    );
    TYPE t_reshab_list IS TABLE OF t_reshab_item;

    g_items t_reshab_list := t_reshab_list();

    -- Inicializacion de coleccion antes de iniciar la sentencia DML
    BEFORE STATEMENT IS
    BEGIN
        g_items.DELETE;
    END BEFORE STATEMENT;

    -- Captura en memoria de cada fila afectada sin consultar la tabla mutante
    AFTER EACH ROW IS
    BEGIN
        g_items.EXTEND;
        g_items(g_items.LAST).id_reserva    := :NEW.id_reserva;
        g_items(g_items.LAST).id_habitacion := :NEW.id_habitacion;
    END AFTER EACH ROW;

    -- Validacion consistente en AFTER STATEMENT (la tabla ya no muta)
    AFTER STATEMENT IS
        v_in_date       DATE;
        v_out_date      DATE;
        v_estado        VARCHAR2(25);
        v_solapamientos NUMBER;
    BEGIN
        FOR i IN 1..g_items.COUNT LOOP
            -- Obtener fechas y estado de la reserva vinculada
            BEGIN
                SELECT TRUNC(fecha_check_in), TRUNC(fecha_check_out), estado
                INTO v_in_date, v_out_date, v_estado
                FROM TURISMO_UQ.RESERVA
                WHERE id_reserva = g_items(i).id_reserva;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(-20005, 'Reserva cabecera no encontrada');
            END;

            -- Solo validar si la reserva se encuentra activa
            IF v_estado != 'CANCELADA' THEN
                -- Consulta cruzada protegida contra mutacion
                SELECT COUNT(*)
                INTO v_solapamientos
                FROM TURISMO_UQ.RESERVA_HABITACION rh
                JOIN TURISMO_UQ.RESERVA r ON rh.id_reserva = r.id_reserva
                WHERE rh.id_habitacion = g_items(i).id_habitacion
                  AND rh.id_reserva <> g_items(i).id_reserva
                  AND r.estado != 'CANCELADA'
                  AND r.fecha_check_in < v_out_date
                  AND r.fecha_check_out > v_in_date;

                IF v_solapamientos > 0 THEN
                    RAISE_APPLICATION_ERROR(-20003, 'Habitacion no disponible por solapamiento de fechas');
                END IF;
            END IF;
        END LOOP;

        g_items.DELETE;
    END AFTER STATEMENT;

END TRG_PREVENIR_SOLAPAMIENTO_RESHAB;
/

SHOW ERRORS TRIGGER TURISMO_UQ.TRG_AUDITORIA_TARIFA;
SHOW ERRORS TRIGGER TURISMO_UQ.TRG_PREVENIR_SOLAPAMIENTO_RESHAB;
