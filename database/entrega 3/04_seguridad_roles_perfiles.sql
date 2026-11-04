-- ============================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- ENTREGA 3 (PUNTO 4): SEGURIDAD, ROLES DIFERENCIADOS, AISLAMIENTO DE RECEPCION
--                      POR VISTAS Y PERFIL DE USUARIO CON LIMITES DE SESION
-- ARCHIVO: database/entrega 3/04_seguridad_roles_perfiles.sql
-- ============================================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = TURISMO_UQ;

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- ============================================================================
-- 1. VISTAS ESPECIALIZADAS PARA EL ROL DE RECEPCION
-- ============================================================================
-- Regla del PDF:
--   "Cuatro roles (recepcion, administrador de alojamiento, gerente, auditor)
--    con privilegios diferenciados; recepcion accede solo a traves de vistas,
--    nunca a tablas directas."
-- ============================================================================

-- Vista 1: VW_RECEPCION_RESERVAS (Consulta operativa de reservas sin exponer tablas base)
CREATE OR REPLACE VIEW TURISMO_UQ.VW_RECEPCION_RESERVAS AS
SELECT
    r.id_reserva,
    r.fecha_creacion,
    r.fecha_check_in,
    r.fecha_check_out,
    (r.fecha_check_out - r.fecha_check_in) AS noches_estadia,
    r.estado AS estado_reserva,
    r.total AS valor_total,
    c.id_cliente,
    c.documento AS documento_cliente,
    c.nombres || ' ' || c.apellidos AS nombre_huesped,
    c.telefono AS telefono_contacto,
    h.id_habitacion,
    h.numero_nombre AS habitacion,
    a.nombre AS alojamiento,
    m.nombre AS municipio
FROM TURISMO_UQ.RESERVA r
JOIN TURISMO_UQ.CLIENTE c             ON r.id_cliente = c.id_cliente
JOIN TURISMO_UQ.RESERVA_HABITACION rh ON r.id_reserva = rh.id_reserva
JOIN TURISMO_UQ.HABITACION h          ON rh.id_habitacion = h.id_habitacion
JOIN TURISMO_UQ.ALOJAMIENTO a         ON h.id_alojamiento = a.id_alojamiento
JOIN TURISMO_UQ.MUNICIPIO m           ON a.id_municipio = m.id_municipio;

-- Trigger INSTEAD OF sobre VW_RECEPCION_RESERVAS para que recepcion pueda actualizar
-- el estado de una reserva (ej. Check-in / Check-out) operando SOLO sobre la vista
CREATE OR REPLACE TRIGGER TURISMO_UQ.TRG_IO_VW_RECEPCION_RESERVAS
INSTEAD OF UPDATE ON TURISMO_UQ.VW_RECEPCION_RESERVAS
FOR EACH ROW
BEGIN
    UPDATE TURISMO_UQ.RESERVA
    SET estado = :NEW.estado_reserva
    WHERE id_reserva = :OLD.id_reserva;
END;
/

-- Vista 2: VW_RECEPCION_CHECKIN (Tablero diario de llegadas y estado de pago)
CREATE OR REPLACE VIEW TURISMO_UQ.VW_RECEPCION_CHECKIN AS
SELECT
    r.id_reserva,
    r.fecha_check_in,
    r.fecha_check_out,
    r.estado AS estado_reserva,
    c.documento AS documento_huesped,
    c.nombres || ' ' || c.apellidos AS huesped,
    a.nombre AS alojamiento,
    h.numero_nombre AS habitacion,
    h.capacidad AS capacidad_maxima,
    NVL(p.estado, 'SIN_REGISTRO') AS estado_pago,
    NVL(p.metodo_pago, 'POR_DEFINIR') AS medio_pago
FROM TURISMO_UQ.RESERVA r
JOIN TURISMO_UQ.CLIENTE c             ON r.id_cliente = c.id_cliente
JOIN TURISMO_UQ.RESERVA_HABITACION rh ON r.id_reserva = rh.id_reserva
JOIN TURISMO_UQ.HABITACION h          ON rh.id_habitacion = h.id_habitacion
JOIN TURISMO_UQ.ALOJAMIENTO a         ON h.id_alojamiento = a.id_alojamiento
LEFT JOIN TURISMO_UQ.PAGO p           ON r.id_reserva = p.id_reserva
WHERE r.estado IN ('CONFIRMADA', 'PENDIENTE');

-- Vista 3: VW_RECEPCION_HABITACIONES_DISP (Catalogo de habitaciones y tarifas vigentes)
CREATE OR REPLACE VIEW TURISMO_UQ.VW_RECEPCION_HABITACIONES_DISP AS
SELECT
    h.id_habitacion,
    h.numero_nombre AS habitacion,
    h.tipo_cama,
    h.capacidad,
    a.id_alojamiento,
    a.nombre AS alojamiento,
    m.nombre AS municipio,
    MAX(CASE WHEN t.id_temporada = 1 THEN t.precio_noche END) AS tarifa_temporada_baja,
    MAX(CASE WHEN t.id_temporada = 2 THEN t.precio_noche END) AS tarifa_temporada_alta
FROM TURISMO_UQ.HABITACION h
JOIN TURISMO_UQ.ALOJAMIENTO a ON h.id_alojamiento = a.id_alojamiento
JOIN TURISMO_UQ.MUNICIPIO m   ON a.id_municipio = m.id_municipio
LEFT JOIN TURISMO_UQ.TARIFA t ON h.id_habitacion = t.id_habitacion
GROUP BY
    h.id_habitacion, h.numero_nombre, h.tipo_cama, h.capacidad,
    a.id_alojamiento, a.nombre, m.nombre;

-- ============================================================================
-- 2. CREACION DE LOS 4 ROLES Y CONCESION DIFERENCIADA DE PRIVILEGIOS
-- ============================================================================
DECLARE
    PROCEDURE pr_crear_rol_seguro(p_rol VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE 'CREATE ROLE ' || p_rol;
        DBMS_OUTPUT.PUT_LINE('Rol creado: ' || p_rol);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -1921 THEN -- ORA-01921: role name conflicts with another user or role name
                DBMS_OUTPUT.PUT_LINE('Rol ya existente (reutilizado): ' || p_rol);
            ELSE
                DBMS_OUTPUT.PUT_LINE('Aviso en creacion de rol ' || p_rol || ': ' || SQLERRM);
            END IF;
    END;

    PROCEDURE pr_grant_seguro(p_sql VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_sql;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Aviso en GRANT [' || p_sql || ']: ' || SQLERRM);
    END;
BEGIN
    -- Crear los 4 roles exigidos por el documento
    pr_crear_rol_seguro('ROL_RECEPCION');
    pr_crear_rol_seguro('ROL_ADMIN_ALOJAMIENTO');
    pr_crear_rol_seguro('ROL_GERENTE');
    pr_crear_rol_seguro('ROL_AUDITOR');

    -- ------------------------------------------------------------------------
    -- A) ROL_RECEPCION: Acceso EXCLUSIVO a traves de vistas (0 tablas directas)
    -- ------------------------------------------------------------------------
    pr_grant_seguro('GRANT SELECT, UPDATE ON TURISMO_UQ.VW_RECEPCION_RESERVAS TO ROL_RECEPCION');
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.VW_RECEPCION_CHECKIN TO ROL_RECEPCION');
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.VW_RECEPCION_HABITACIONES_DISP TO ROL_RECEPCION');

    -- Garantizar explicitamente que ROL_RECEPCION no tenga permisos sobre tablas base
    BEGIN EXECUTE IMMEDIATE 'REVOKE ALL ON TURISMO_UQ.RESERVA FROM ROL_RECEPCION'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'REVOKE ALL ON TURISMO_UQ.HABITACION FROM ROL_RECEPCION'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'REVOKE ALL ON TURISMO_UQ.CLIENTE FROM ROL_RECEPCION'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'REVOKE ALL ON TURISMO_UQ.PAGO FROM ROL_RECEPCION'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'REVOKE ALL ON TURISMO_UQ.TARIFA FROM ROL_RECEPCION'; EXCEPTION WHEN OTHERS THEN NULL; END;

    -- ------------------------------------------------------------------------
    -- B) ROL_ADMIN_ALOJAMIENTO: Gestion operativa de alojamientos, habitaciones y tarifas
    -- ------------------------------------------------------------------------
    pr_grant_seguro('GRANT SELECT, INSERT, UPDATE ON TURISMO_UQ.ALOJAMIENTO TO ROL_ADMIN_ALOJAMIENTO');
    pr_grant_seguro('GRANT SELECT, INSERT, UPDATE ON TURISMO_UQ.HABITACION TO ROL_ADMIN_ALOJAMIENTO');
    pr_grant_seguro('GRANT SELECT, INSERT, UPDATE ON TURISMO_UQ.TARIFA TO ROL_ADMIN_ALOJAMIENTO');
    pr_grant_seguro('GRANT SELECT, INSERT, UPDATE ON TURISMO_UQ.SERVICIO TO ROL_ADMIN_ALOJAMIENTO');
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.TEMPORADA TO ROL_ADMIN_ALOJAMIENTO');
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.PERIODO_TEMPORADA TO ROL_ADMIN_ALOJAMIENTO');
    pr_grant_seguro('GRANT EXECUTE ON TURISMO_UQ.PKG_TURISMO_RESERVAS TO ROL_ADMIN_ALOJAMIENTO');

    -- ------------------------------------------------------------------------
    -- C) ROL_GERENTE: Lectura analitica, vistas materializadas y liquidaciones
    -- ------------------------------------------------------------------------
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.MV_OCUPACION_MENSUAL TO ROL_GERENTE');
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.LIQUIDACION_MENSUAL_HISTORICO TO ROL_GERENTE');
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.RESERVA TO ROL_GERENTE');
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.RESERVA_HABITACION TO ROL_GERENTE');
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.RESERVA_SERVICIO TO ROL_GERENTE');
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.PAGO TO ROL_GERENTE');
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.ALOJAMIENTO TO ROL_GERENTE');
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.MUNICIPIO TO ROL_GERENTE');
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.RESENA TO ROL_GERENTE');

    -- ------------------------------------------------------------------------
    -- D) ROL_AUDITOR: Fiscalizacion inmutable de bitacoras de tarifas y planes
    -- ------------------------------------------------------------------------
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.AUDITORIA_TARIFA TO ROL_AUDITOR');
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.LOG_SENTENCIA_TARIFA TO ROL_AUDITOR');
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.AUDITORIA_PLANES_INDICES TO ROL_AUDITOR');
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.TARIFA TO ROL_AUDITOR');
    pr_grant_seguro('GRANT SELECT ON TURISMO_UQ.USUARIO_SISTEMA TO ROL_AUDITOR');
END;
/

-- ============================================================================
-- 3. PERFIL DE USUARIO CON LIMITES DE SESION Y CONEXION
-- ============================================================================
-- Regla del PDF:
--   "Un perfil de usuario con limites de sesion y conexion."
-- ============================================================================
DECLARE
BEGIN
    EXECUTE IMMEDIATE '
        CREATE PROFILE PERFIL_TURISMO_OPERATIVO LIMIT
            SESSIONS_PER_USER          2
            IDLE_TIME                  30
            CONNECT_TIME               480
            FAILED_LOGIN_ATTEMPTS      3
            PASSWORD_LIFE_TIME         90
            PASSWORD_LOCK_TIME         1
            PASSWORD_GRACE_TIME        7
    ';
    DBMS_OUTPUT.PUT_LINE('Perfil PERFIL_TURISMO_OPERATIVO creado exitosamente.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -2379 THEN -- ORA-02379: profile already exists
            EXECUTE IMMEDIATE '
                ALTER PROFILE PERFIL_TURISMO_OPERATIVO LIMIT
                    SESSIONS_PER_USER          2
                    IDLE_TIME                  30
                    CONNECT_TIME               480
                    FAILED_LOGIN_ATTEMPTS      3
                    PASSWORD_LIFE_TIME         90
                    PASSWORD_LOCK_TIME         1
                    PASSWORD_GRACE_TIME        7
            ';
            DBMS_OUTPUT.PUT_LINE('Perfil PERFIL_TURISMO_OPERATIVO actualizado exitosamente.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Nota sobre perfil PERFIL_TURISMO_OPERATIVO: ' || SQLERRM);
        END IF;
END;
/

-- ============================================================================
-- 4. TABLAS DE METADATOS DE SEGURIDAD PARA VERIFICACION Y AUDITORIA EN APP
-- ============================================================================
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE TURISMO_UQ.CATALOGO_SEGURIDAD_ROLES PURGE';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE TURISMO_UQ.CATALOGO_PERFIL_LIMITES PURGE';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE TURISMO_UQ.CATALOGO_SEGURIDAD_ROLES (
    id_rol              NUMBER PRIMARY KEY,
    nombre_rol          VARCHAR2(50) NOT NULL UNIQUE,
    titulo_rol          VARCHAR2(100) NOT NULL,
    acceso_tablas_base  VARCHAR2(60) NOT NULL,
    objetos_permitidos  VARCHAR2(500) NOT NULL,
    privilegios_dml     VARCHAR2(150) NOT NULL,
    aislamiento_vistas  CHAR(1) DEFAULT 'N' CHECK (aislamiento_vistas IN ('S', 'N')),
    justificacion       VARCHAR2(600) NOT NULL
);

INSERT INTO TURISMO_UQ.CATALOGO_SEGURIDAD_ROLES VALUES (
    1, 'ROL_RECEPCION', 'Operador de Recepcion y Check-In',
    'DENEGADO (0 Tablas)',
    'VW_RECEPCION_RESERVAS, VW_RECEPCION_CHECKIN, VW_RECEPCION_HABITACIONES_DISP',
    'SELECT (3 Vistas), UPDATE de estado via Trigger INSTEAD OF',
    'S',
    'Cumple el principio de minimo privilegio exigido: el personal de recepcion nunca accede a las tablas RESERVA, CLIENTE, HABITACION ni PAGO directamente; opera exclusivamente mediante 3 vistas desnormalizadas y seguras.'
);

INSERT INTO TURISMO_UQ.CATALOGO_SEGURIDAD_ROLES VALUES (
    2, 'ROL_ADMIN_ALOJAMIENTO', 'Administrador de Alojamiento y Tarifas',
    'AUTORIZADO (6 Tablas)',
    'ALOJAMIENTO, HABITACION, TARIFA, SERVICIO, TEMPORADA, PERIODO_TEMPORADA, PKG_TURISMO_RESERVAS',
    'SELECT, INSERT, UPDATE + EXECUTE en Paquete PL/SQL',
    'N',
    'Gestiona la capacidad instalada de los alojamientos, la configuracion de habitaciones y la actualizacion de tarifas por temporada alta/baja (disparando automaticamente el trigger de auditoria).'
);

INSERT INTO TURISMO_UQ.CATALOGO_SEGURIDAD_ROLES VALUES (
    3, 'ROL_GERENTE', 'Gerente de Inteligencia de Negocios',
    'SOLO LECTURA (9 Objetos)',
    'MV_OCUPACION_MENSUAL, LIQUIDACION_MENSUAL_HISTORICO, RESERVA, PAGO, ALOJAMIENTO, MUNICIPIO, RESENA',
    'SELECT (Solo Lectura Analitica)',
    'N',
    'Acceso de lectura sobre las vistas materializadas, el historico de liquidaciones en TBS_HISTORICO_RESERVAS y las tablas de ingresos para ejecutar las 8 consultas analiticas sin riesgo de alteracion de datos.'
);

INSERT INTO TURISMO_UQ.CATALOGO_SEGURIDAD_ROLES VALUES (
    4, 'ROL_AUDITOR', 'Auditor Interno de Tarifas y Rendimiento',
    'SOLO LECTURA (5 Tablas)',
    'AUDITORIA_TARIFA, LOG_SENTENCIA_TARIFA, AUDITORIA_PLANES_INDICES, TARIFA, USUARIO_SISTEMA',
    'SELECT (Inmutable / Sin permisos de escritura)',
    'N',
    'Fiscaliza el rastro dejado por los triggers de fila y de sentencia sobre cambios en tarifas, asi como los planes de ejecucion medidos, sin facultad para modificar registros ni borrar huellas.'
);

CREATE TABLE TURISMO_UQ.CATALOGO_PERFIL_LIMITES (
    id_parametro    NUMBER PRIMARY KEY,
    nombre_perfil   VARCHAR2(50) NOT NULL,
    recurso         VARCHAR2(50) NOT NULL,
    valor_limite    VARCHAR2(50) NOT NULL,
    unidad          VARCHAR2(60) NOT NULL,
    proposito       VARCHAR2(400) NOT NULL
);

INSERT INTO TURISMO_UQ.CATALOGO_PERFIL_LIMITES VALUES (
    1, 'PERFIL_TURISMO_OPERATIVO', 'SESSIONS_PER_USER', '2', 'Sesiones simultaneas max.',
    'Impide que un mismo operador abra mas de 2 conexiones concurrentes, previniendo agotamiento del pool de procesos en Oracle XE.'
);
INSERT INTO TURISMO_UQ.CATALOGO_PERFIL_LIMITES VALUES (
    2, 'PERFIL_TURISMO_OPERATIVO', 'IDLE_TIME', '30', 'Minutos de inactividad max.',
    'Cierra automaticamente sesiones abandonadas en terminales de recepcion tras 30 minutos sin actividad para liberar bloqueos de fila.'
);
INSERT INTO TURISMO_UQ.CATALOGO_PERFIL_LIMITES VALUES (
    3, 'PERFIL_TURISMO_OPERATIVO', 'CONNECT_TIME', '480', 'Minutos por turno (8 horas)',
    'Limita la duracion continua maxima de una sesion al turno laboral estandar de 8 horas.'
);
INSERT INTO TURISMO_UQ.CATALOGO_PERFIL_LIMITES VALUES (
    4, 'PERFIL_TURISMO_OPERATIVO', 'FAILED_LOGIN_ATTEMPTS', '3', 'Intentos fallidos antes de bloqueo',
    'Mitiga ataques de fuerza bruta bloqueando la cuenta tras 3 intentos consecutivos de contrasena erronea.'
);
INSERT INTO TURISMO_UQ.CATALOGO_PERFIL_LIMITES VALUES (
    5, 'PERFIL_TURISMO_OPERATIVO', 'PASSWORD_LIFE_TIME', '90', 'Dias de vigencia de credencial',
    'Exige rotacion periodica trimestral de contrasenas para cumplir politicas de seguridad operativa.'
);

COMMIT;

PROMPT Vistas de recepcion, 4 roles y perfil PERFIL_TURISMO_OPERATIVO configurados exitosamente.
