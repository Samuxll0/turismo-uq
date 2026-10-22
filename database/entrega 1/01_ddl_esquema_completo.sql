-- ============================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- ENTREGA 1: SCRIPT DDL COMPLETO DE DEFINICION DEL ESQUEMA RELACIONAL
-- MODELO MINIMO DE 14 ENTIDADES + RESTRICCIONES (PK, FK, CHECK, NOT NULL, UNIQUE)
-- MOTOR: ORACLE DATABASE 21c EXPRESS EDITION (PDB: XEPDB1)
-- ESQUEMA: TURISMO_UQ
-- ============================================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = TURISMO_UQ;

-- ============================================================================
-- 1. LIMPIEZA PREVIA ORDENADA (DROP TABLES SI EXISTEN)
-- ============================================================================
BEGIN
    FOR t IN (
        SELECT table_name FROM user_tables 
        WHERE table_name IN (
            'RESENA', 'PAGO', 'RESERVA_SERVICIO', 'RESERVA_HABITACION', 
            'RESERVA', 'TARIFA', 'PERIODO_TEMPORADA', 'TEMPORADA', 
            'HABITACION', 'ALOJAMIENTO', 'TIPO_ALOJAMIENTO', 'MUNICIPIO', 
            'SERVICIO', 'CLIENTE', 'USUARIO_SISTEMA', 'AUDITORIA_TARIFA',
            'LOG_SENTENCIA_TARIFA', 'LIQUIDACION_MENSUAL_HISTORICO'
        )
    ) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
    END LOOP;
END;
/

-- ============================================================================
-- 2. ENTIDADES MAESTRAS Y CATALOGOS BASE
-- ============================================================================

-- Entidad 1: MUNICIPIO (12 Municipios del Departamento del Quindío)
CREATE TABLE MUNICIPIO (
    id_municipio    NUMBER GENERATED ALWAYS AS IDENTITY,
    nombre          VARCHAR2(60) NOT NULL,
    CONSTRAINT pk_municipio PRIMARY KEY (id_municipio),
    CONSTRAINT uk_municipio_nombre UNIQUE (nombre)
);

-- Entidad 2: TIPO_ALOJAMIENTO (Hotel, Finca Tradicional, Eco-Glamping, etc.)
CREATE TABLE TIPO_ALOJAMIENTO (
    id_tipo_alojamiento NUMBER GENERATED ALWAYS AS IDENTITY,
    nombre              VARCHAR2(60) NOT NULL,
    descripcion         VARCHAR2(250),
    CONSTRAINT pk_tipo_alojamiento PRIMARY KEY (id_tipo_alojamiento),
    CONSTRAINT uk_tipo_aloj_nombre UNIQUE (nombre)
);

-- Entidad 3: ALOJAMIENTO (60 Alojamientos distribuidos en los 12 municipios)
CREATE TABLE ALOJAMIENTO (
    id_alojamiento      NUMBER GENERATED ALWAYS AS IDENTITY,
    nombre              VARCHAR2(100) NOT NULL,
    direccion           VARCHAR2(150) NOT NULL,
    telefono            VARCHAR2(30),
    id_municipio        NUMBER NOT NULL,
    id_tipo_alojamiento NUMBER NOT NULL,
    CONSTRAINT pk_alojamiento PRIMARY KEY (id_alojamiento),
    CONSTRAINT fk_aloj_municipio FOREIGN KEY (id_municipio) 
        REFERENCES MUNICIPIO(id_municipio),
    CONSTRAINT fk_aloj_tipo FOREIGN KEY (id_tipo_alojamiento) 
        REFERENCES TIPO_ALOJAMIENTO(id_tipo_alojamiento)
);

-- Entidad 4: HABITACION (400 Habitaciones distribuidas en los 60 alojamientos)
CREATE TABLE HABITACION (
    id_habitacion   NUMBER GENERATED ALWAYS AS IDENTITY,
    numero_nombre   VARCHAR2(50) NOT NULL,
    capacidad       NUMBER(2) NOT NULL,
    tipo_cama       VARCHAR2(50) NOT NULL,
    id_alojamiento  NUMBER NOT NULL,
    CONSTRAINT pk_habitacion PRIMARY KEY (id_habitacion),
    CONSTRAINT fk_hab_alojamiento FOREIGN KEY (id_alojamiento) 
        REFERENCES ALOJAMIENTO(id_alojamiento) ON DELETE CASCADE,
    CONSTRAINT uk_hab_numero_aloj UNIQUE (id_alojamiento, numero_nombre),
    CONSTRAINT chk_hab_capacidad CHECK (capacidad > 0 AND capacidad <= 20)
);

-- Entidad 5: TEMPORADA (ID 1: Baja, ID 2: Alta)
CREATE TABLE TEMPORADA (
    id_temporada    NUMBER GENERATED ALWAYS AS IDENTITY,
    nombre          VARCHAR2(50) NOT NULL,
    CONSTRAINT pk_temporada PRIMARY KEY (id_temporada),
    CONSTRAINT uk_temporada_nombre UNIQUE (nombre)
);

-- Entidad Complementaria: PERIODO_TEMPORADA (Ventanas de alta demanda para cálculo día a día)
CREATE TABLE PERIODO_TEMPORADA (
    id_periodo      NUMBER GENERATED ALWAYS AS IDENTITY,
    id_temporada    NUMBER NOT NULL,
    nombre          VARCHAR2(80) NOT NULL,
    fecha_inicio    DATE NOT NULL,
    fecha_fin       DATE NOT NULL,
    CONSTRAINT pk_periodo_temporada PRIMARY KEY (id_periodo),
    CONSTRAINT fk_periodo_temporada FOREIGN KEY (id_temporada) 
        REFERENCES TEMPORADA(id_temporada),
    CONSTRAINT chk_periodo_fechas CHECK (fecha_fin >= fecha_inicio)
);

-- Entidad 6: TARIFA (800 Tarifas: 1 tarifa baja y 1 tarifa alta por habitación)
CREATE TABLE TARIFA (
    id_tarifa       NUMBER GENERATED ALWAYS AS IDENTITY,
    precio_noche    NUMBER(12,2) NOT NULL,
    id_temporada    NUMBER NOT NULL,
    id_habitacion   NUMBER NOT NULL,
    CONSTRAINT pk_tarifa PRIMARY KEY (id_tarifa),
    CONSTRAINT fk_tarifa_temporada FOREIGN KEY (id_temporada) 
        REFERENCES TEMPORADA(id_temporada),
    CONSTRAINT fk_tarifa_habitacion FOREIGN KEY (id_habitacion) 
        REFERENCES HABITACION(id_habitacion) ON DELETE CASCADE,
    CONSTRAINT uk_tarifa_hab_temp UNIQUE (id_habitacion, id_temporada),
    CONSTRAINT chk_tarifa_precio CHECK (precio_noche > 0)
);

-- Entidad 7: CLIENTE (3.000 Clientes)
CREATE TABLE CLIENTE (
    id_cliente      NUMBER GENERATED ALWAYS AS IDENTITY,
    nombres         VARCHAR2(80) NOT NULL,
    apellidos       VARCHAR2(80) NOT NULL,
    documento       VARCHAR2(20) NOT NULL,
    correo          VARCHAR2(100) NOT NULL,
    telefono        VARCHAR2(30),
    CONSTRAINT pk_cliente PRIMARY KEY (id_cliente),
    CONSTRAINT uk_cliente_documento UNIQUE (documento),
    CONSTRAINT uk_cliente_correo UNIQUE (correo)
);

-- Entidad 8: RESERVA (25.000 Reservas repartidas entre 2024 y 2026)
CREATE TABLE RESERVA (
    id_reserva          NUMBER GENERATED ALWAYS AS IDENTITY,
    fecha_creacion      DATE DEFAULT SYSDATE NOT NULL,
    fecha_check_in      DATE NOT NULL,
    fecha_check_out     DATE NOT NULL,
    total               NUMBER(14,2) DEFAULT 0 NOT NULL,
    estado              VARCHAR2(25) DEFAULT 'CONFIRMADA' NOT NULL,
    id_cliente          NUMBER NOT NULL,
    CONSTRAINT pk_reserva PRIMARY KEY (id_reserva),
    CONSTRAINT fk_reserva_cliente FOREIGN KEY (id_cliente) 
        REFERENCES CLIENTE(id_cliente),
    CONSTRAINT chk_reserva_fechas CHECK (fecha_check_out > fecha_check_in),
    CONSTRAINT chk_reserva_estado CHECK (estado IN ('CONFIRMADA', 'CANCELADA', 'PENDIENTE', 'FINALIZADA'))
);

-- Entidad 9: RESERVA_HABITACION (Relación M:N que permite reservas multihabitación)
CREATE TABLE RESERVA_HABITACION (
    id_reserva      NUMBER NOT NULL,
    id_habitacion   NUMBER NOT NULL,
    precio_unitario NUMBER(12,2) NOT NULL,
    subtotal        NUMBER(14,2) NOT NULL,
    CONSTRAINT pk_reserva_habitacion PRIMARY KEY (id_reserva, id_habitacion),
    CONSTRAINT fk_reshab_reserva FOREIGN KEY (id_reserva) 
        REFERENCES RESERVA(id_reserva) ON DELETE CASCADE,
    CONSTRAINT fk_reshab_habitacion FOREIGN KEY (id_habitacion) 
        REFERENCES HABITACION(id_habitacion),
    CONSTRAINT chk_reshab_subtotal CHECK (subtotal >= 0)
);

-- Entidad 10: SERVICIO (Servicios turísticos complementarios del Quindío)
CREATE TABLE SERVICIO (
    id_servicio     NUMBER GENERATED ALWAYS AS IDENTITY,
    nombre          VARCHAR2(100) NOT NULL,
    descripcion     VARCHAR2(250),
    precio          NUMBER(12,2) NOT NULL,
    CONSTRAINT pk_servicio PRIMARY KEY (id_servicio),
    CONSTRAINT chk_servicio_precio CHECK (precio >= 0)
);

-- Entidad 11: RESERVA_SERVICIO (40.000 Líneas de consumo de servicios turísticos)
CREATE TABLE RESERVA_SERVICIO (
    id_reserva_servicio NUMBER GENERATED ALWAYS AS IDENTITY,
    id_reserva          NUMBER NOT NULL,
    id_servicio         NUMBER NOT NULL,
    cantidad            NUMBER(3) DEFAULT 1 NOT NULL,
    precio_unitario     NUMBER(12,2) NOT NULL,
    subtotal            NUMBER(14,2) NOT NULL,
    CONSTRAINT pk_reserva_servicio PRIMARY KEY (id_reserva_servicio),
    CONSTRAINT fk_resserv_reserva FOREIGN KEY (id_reserva) 
        REFERENCES RESERVA(id_reserva) ON DELETE CASCADE,
    CONSTRAINT fk_resserv_servicio FOREIGN KEY (id_servicio) 
        REFERENCES SERVICIO(id_servicio),
    CONSTRAINT chk_resserv_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_resserv_subtotal CHECK (subtotal >= 0)
);

-- Entidad 12: PAGO (25.000 Pagos atómicos)
CREATE TABLE PAGO (
    id_pago         NUMBER GENERATED ALWAYS AS IDENTITY,
    id_reserva      NUMBER NOT NULL,
    monto           NUMBER(14,2) NOT NULL,
    fecha_pago      DATE DEFAULT SYSDATE NOT NULL,
    metodo_pago     VARCHAR2(50) DEFAULT 'TARJETA' NOT NULL,
    estado          VARCHAR2(25) DEFAULT 'APROBADO' NOT NULL,
    CONSTRAINT pk_pago PRIMARY KEY (id_pago),
    CONSTRAINT fk_pago_reserva FOREIGN KEY (id_reserva) 
        REFERENCES RESERVA(id_reserva),
    CONSTRAINT chk_pago_monto CHECK (monto > 0),
    CONSTRAINT chk_pago_metodo CHECK (metodo_pago IN ('TARJETA', 'TRANSFERENCIA', 'EFECTIVO', 'PSE')),
    CONSTRAINT chk_pago_estado CHECK (estado IN ('APROBADO', 'RECHAZADO', 'PENDIENTE'))
);

-- Entidad 13: RESENA (Evaluaciones y calificaciones de huéspedes)
CREATE TABLE RESENA (
    id_resena       NUMBER GENERATED ALWAYS AS IDENTITY,
    id_reserva      NUMBER NOT NULL,
    calificacion    NUMBER(2,1) NOT NULL,
    comentario      VARCHAR2(500),
    fecha_resena    DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_resena PRIMARY KEY (id_resena),
    CONSTRAINT fk_resena_reserva FOREIGN KEY (id_reserva) 
        REFERENCES RESERVA(id_reserva) ON DELETE CASCADE,
    CONSTRAINT chk_resena_calificacion CHECK (calificacion BETWEEN 1.0 AND 5.0)
);

-- Entidad 14: USUARIO_SISTEMA (Control de acceso y perfiles de sesión)
CREATE TABLE USUARIO_SISTEMA (
    id_usuario      NUMBER GENERATED ALWAYS AS IDENTITY,
    username        VARCHAR2(50) NOT NULL,
    password_hash   VARCHAR2(255) NOT NULL,
    rol             VARCHAR2(50) NOT NULL,
    activo          NUMBER(1) DEFAULT 1 NOT NULL,
    CONSTRAINT pk_usuario_sistema PRIMARY KEY (id_usuario),
    CONSTRAINT uk_usuario_username UNIQUE (username),
    CONSTRAINT chk_usuario_rol CHECK (rol IN ('RECEPCION', 'ADMIN_ALOJAMIENTO', 'GERENTE', 'AUDITOR')),
    CONSTRAINT chk_usuario_activo CHECK (activo IN (0, 1))
);

-- ============================================================================
-- 3. TABLAS DE AUDITORIA Y CIERRE HISTORICO (ENTREGA 2)
-- ============================================================================

-- Tabla de Auditoría de Tarifas (Detalle fila por fila: viejo, nuevo, usuario)
CREATE TABLE AUDITORIA_TARIFA (
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
    CONSTRAINT chk_auditoria_accion CHECK (accion IN ('INSERT', 'UPDATE', 'DELETE'))
);

-- Tabla de Log a Nivel de Sentencia (Auditoría por bloque DML)
CREATE TABLE LOG_SENTENCIA_TARIFA (
    id_log              NUMBER GENERATED ALWAYS AS IDENTITY,
    usuario             VARCHAR2(60) NOT NULL,
    fecha               DATE DEFAULT SYSDATE NOT NULL,
    accion              VARCHAR2(10) NOT NULL,
    total_filas         NUMBER NOT NULL,
    CONSTRAINT pk_log_sentencia_tarifa PRIMARY KEY (id_log),
    CONSTRAINT chk_log_accion CHECK (accion IN ('INSERT', 'UPDATE', 'DELETE'))
);

-- Tabla de Liquidación Mensual Histórica (Destinada a TBS_HISTORICO_RESERVAS)
CREATE TABLE LIQUIDACION_MENSUAL_HISTORICO (
    id_liquidacion      NUMBER GENERATED ALWAYS AS IDENTITY,
    anio                NUMBER(4) NOT NULL,
    mes                 NUMBER(2) NOT NULL,
    id_alojamiento      NUMBER NOT NULL,
    total_reservas      NUMBER(10) DEFAULT 0 NOT NULL,
    total_hospedaje     NUMBER(14,2) DEFAULT 0 NOT NULL,
    total_servicios     NUMBER(14,2) DEFAULT 0 NOT NULL,
    total_ingresos      NUMBER(14,2) DEFAULT 0 NOT NULL,
    fecha_liquidacion   DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_liq_mensual_hist PRIMARY KEY (id_liquidacion),
    CONSTRAINT fk_liq_hist_alojamiento FOREIGN KEY (id_alojamiento) 
        REFERENCES ALOJAMIENTO(id_alojamiento),
    CONSTRAINT uk_liq_hist_periodo UNIQUE (anio, mes, id_alojamiento),
    CONSTRAINT chk_liq_mes CHECK (mes BETWEEN 1 AND 12)
);

-- ============================================================================
-- 4. INDICES ESTRATEGICOS DE BUSQUEDA
-- ============================================================================
CREATE INDEX idx_hab_alojamiento ON HABITACION(id_alojamiento);
CREATE INDEX idx_tarifa_habitacion ON TARIFA(id_habitacion);
CREATE INDEX idx_reserva_fechas ON RESERVA(fecha_check_in, fecha_check_out);
CREATE INDEX idx_reserva_cliente ON RESERVA(id_cliente);
CREATE INDEX idx_reshab_habitacion ON RESERVA_HABITACION(id_habitacion);
CREATE INDEX idx_resserv_reserva ON RESERVA_SERVICIO(id_reserva);
CREATE INDEX idx_pago_reserva ON PAGO(id_reserva);
CREATE INDEX idx_periodo_temp_fechas ON PERIODO_TEMPORADA(id_temporada, fecha_inicio, fecha_fin);

PROMPT Tablas e indices del esquema relacional TURISMO_UQ creados exitosamente.
