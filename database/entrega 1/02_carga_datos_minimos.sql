-- ============================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- ENTREGA 1: POBLACION Y GENERACION REPRODUCIBLE DE DATOS MINIMOS
-- VOLUMEN EXIGIDO EN PDF:
--   - 12 Municipios
--   - 60 Alojamientos
--   - 400 Habitaciones
--   - 3.000 Clientes
--   - 25.000 Reservas (2024 - 2026)
--   - 40.000 Líneas de consumo en RESERVA_SERVICIO
--   - 25.000 Pagos atómicos
--   - 800 Tarifas (400 baja + 400 alta con recargo del +40%)
--   - 4 Usuarios del sistema
-- MOTOR: ORACLE XE 21c (PDB: XEPDB1)
-- ============================================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = TURISMO_UQ;

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET TIMING ON;

PROMPT ============================================================================
PROMPT === INICIANDO POBLACION DE VOLUMEN MINIMO DE DATOS TURISMOUQ            ===
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- 1. POBLACION DE MUNICIPIOS (12 Oficiales del Quindío)
-- ----------------------------------------------------------------------------
INSERT INTO MUNICIPIO (nombre) VALUES ('Armenia');
INSERT INTO MUNICIPIO (nombre) VALUES ('Buenavista');
INSERT INTO MUNICIPIO (nombre) VALUES ('Calarca');
INSERT INTO MUNICIPIO (nombre) VALUES ('Circasia');
INSERT INTO MUNICIPIO (nombre) VALUES ('Cordoba');
INSERT INTO MUNICIPIO (nombre) VALUES ('Filandia');
INSERT INTO MUNICIPIO (nombre) VALUES ('Genova');
INSERT INTO MUNICIPIO (nombre) VALUES ('La Tebaida');
INSERT INTO MUNICIPIO (nombre) VALUES ('Montenegro');
INSERT INTO MUNICIPIO (nombre) VALUES ('Pijao');
INSERT INTO MUNICIPIO (nombre) VALUES ('Quimbaya');
INSERT INTO MUNICIPIO (nombre) VALUES ('Salento');
COMMIT;
PROMPT [1/9] 12 Municipios insertados.

-- ----------------------------------------------------------------------------
-- 2. POBLACION DE TIPOS DE ALOJAMIENTO
-- ----------------------------------------------------------------------------
INSERT INTO TIPO_ALOJAMIENTO (nombre, descripcion) 
VALUES ('Hacienda Cafetera', 'Arquitectura tipica de la colonizacion antioquena inmersa en cafetales');
INSERT INTO TIPO_ALOJAMIENTO (nombre, descripcion) 
VALUES ('Eco-Glamping', 'Domo geodésico y tiendas safari con vistas panoramicas a la cordillera');
INSERT INTO TIPO_ALOJAMIENTO (nombre, descripcion) 
VALUES ('Hotel Boutique', 'Establecimiento de alto confort con atencion personalizada y spa');
INSERT INTO TIPO_ALOJAMIENTO (nombre, descripcion) 
VALUES ('Finca Tradicional', 'Alojamiento rural autentico con senderos ecologicos y fauna nativa');
COMMIT;
PROMPT [2/9] 4 Tipos de alojamiento insertados.

-- ----------------------------------------------------------------------------
-- 3. POBLACION DE TEMPORADAS Y PERIODOS DE ALTA DEMANDA
-- ----------------------------------------------------------------------------
INSERT INTO TEMPORADA (nombre) VALUES ('TEMPORADA BAJA');
INSERT INTO TEMPORADA (nombre) VALUES ('TEMPORADA ALTA');
COMMIT;

-- Ventanas de temporada alta (Semana Santa, Mitad de Año, Fin de Año) 2024-2026
INSERT INTO PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
VALUES (2, 'Semana Santa 2024', DATE '2024-03-23', DATE '2024-03-31');
INSERT INTO PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
VALUES (2, 'Mitad de Anio 2024', DATE '2024-06-15', DATE '2024-07-20');
INSERT INTO PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
VALUES (2, 'Fin de Anio 2024', DATE '2024-12-15', DATE '2025-01-15');

INSERT INTO PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
VALUES (2, 'Semana Santa 2025', DATE '2025-04-12', DATE '2025-04-20');
INSERT INTO PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
VALUES (2, 'Mitad de Anio 2025', DATE '2025-06-14', DATE '2025-07-19');
INSERT INTO PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
VALUES (2, 'Fin de Anio 2025', DATE '2025-12-15', DATE '2026-01-15');

INSERT INTO PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
VALUES (2, 'Semana Santa 2026', DATE '2026-03-28', DATE '2026-04-05');
INSERT INTO PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
VALUES (2, 'Mitad de Anio 2026', DATE '2026-06-15', DATE '2026-07-20');
INSERT INTO PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
VALUES (2, 'Fin de Anio 2026', DATE '2026-12-15', DATE '2027-01-15');
COMMIT;
PROMPT [3/9] 2 Temporadas y 9 Periodos de Temporada Alta configurados.

-- ----------------------------------------------------------------------------
-- 4. POBLACION DE ALOJAMIENTOS (Exactamente 60: 5 por municipio)
-- ----------------------------------------------------------------------------
DECLARE
    TYPE t_nombres IS TABLE OF VARCHAR2(60);
    v_nombres_base t_nombres := t_nombres(
        'Hacienda San Alberto', 'Glamping Entre Nubes', 'Finca El Paraiso', 'Eco-Hotel Bosque de Niebla',
        'Posada Cafetera La Soledad', 'Hostería del Cafe', 'Reserva La Morelia', 'Finca Hotel Las Palmas',
        'Cabañas El Ocaso', 'Mirador Valle del Cocora', 'Hacienda Combia', 'Glamping Los Guaduales'
    );
    v_mun_id NUMBER;
    v_tipo_id NUMBER;
    v_aloj_count NUMBER := 0;
BEGIN
    FOR m IN (SELECT id_municipio, nombre FROM MUNICIPIO ORDER BY id_municipio) LOOP
        FOR i IN 1..5 LOOP
            v_aloj_count := v_aloj_count + 1;
            v_tipo_id := MOD(v_aloj_count, 4) + 1;
            INSERT INTO ALOJAMIENTO (nombre, direccion, telefono, id_municipio, id_tipo_alojamiento)
            VALUES (
                v_nombres_base(MOD(v_aloj_count - 1, v_nombres_base.COUNT) + 1) || ' ' || m.nombre || ' #' || i,
                'Vereda ' || m.nombre || ' Km ' || (i * 2),
                '31' || TRUNC(DBMS_RANDOM.VALUE(0, 9)) || TRUNC(DBMS_RANDOM.VALUE(1000000, 9999999)),
                m.id_municipio,
                v_tipo_id
            );
        END LOOP;
    END LOOP;
    COMMIT;
END;
/
PROMPT [4/9] 60 Alojamientos distribuidos uniformemente en 12 municipios.

-- ----------------------------------------------------------------------------
-- 5. POBLACION DE HABITACIONES (Exactamente 400 habitaciones)
--    Y TARIFAS (Exactamente 800 tarifas: 400 baja + 400 alta con recargo +40%)
-- ----------------------------------------------------------------------------
DECLARE
    TYPE t_camas IS TABLE OF VARCHAR2(30);
    v_camas t_camas := t_camas('Cama King', 'Cama Queen', 'Dos Camas Dobles', 'Familiar Suite');
    v_hab_total NUMBER := 0;
    v_hab_por_aloj NUMBER;
    v_tarifa_baja NUMBER;
    v_tarifa_alta NUMBER;
    v_id_hab NUMBER;
BEGIN
    FOR a IN (SELECT id_alojamiento FROM ALOJAMIENTO ORDER BY id_alojamiento) LOOP
        -- Distribuir entre 6 y 8 habitaciones por alojamiento para totalizar 400
        IF a.id_alojamiento <= 40 THEN
            v_hab_por_aloj := 7;
        ELSE
            v_hab_por_aloj := 6;
        END IF;

        FOR h IN 1..v_hab_por_aloj LOOP
            v_hab_total := v_hab_total + 1;
            EXIT WHEN v_hab_total > 400;

            INSERT INTO HABITACION (numero_nombre, capacidad, tipo_cama, id_alojamiento)
            VALUES (
                'Habitacion ' || (100 + h),
                MOD(h, 4) + 2, -- Capacidad entre 2 y 5 personas
                v_camas(MOD(h - 1, 4) + 1),
                a.id_alojamiento
            ) RETURNING id_habitacion INTO v_id_hab;

            -- Generar Tarifa Baja redondeada a miles
            v_tarifa_baja := ROUND(DBMS_RANDOM.VALUE(130000, 290000), -3);
            -- Tarifa Alta: exactamente +40% sobre la baja
            v_tarifa_alta := ROUND(v_tarifa_baja * 1.40, -3);

            -- Tarifa Temporada Baja (ID 1)
            INSERT INTO TARIFA (precio_noche, id_temporada, id_habitacion)
            VALUES (v_tarifa_baja, 1, v_id_hab);

            -- Tarifa Temporada Alta (ID 2)
            INSERT INTO TARIFA (precio_noche, id_temporada, id_habitacion)
            VALUES (v_tarifa_alta, 2, v_id_hab);
        END LOOP;
    END LOOP;
    COMMIT;
END;
/
PROMPT [5/9] 400 Habitaciones creadas y 800 Tarifas calculadas con regla +40%.

-- ----------------------------------------------------------------------------
-- 6. POBLACION DE CLIENTES (Exactamente 3.000 clientes con datos únicos)
-- ----------------------------------------------------------------------------
DECLARE
    TYPE t_str_tab IS TABLE OF VARCHAR2(50);
    v_nombres t_str_tab := t_str_tab('Carlos', 'Maria', 'Juan', 'Laura', 'Andres', 'Camila', 'Santiago', 'Valentina', 'Felipe', 'Daniela', 'Mateo', 'Sofia');
    v_apellidos t_str_tab := t_str_tab('Gomez', 'Rodriguez', 'Lopez', 'Hernandez', 'Martinez', 'Perez', 'Garcia', 'Sanchez', 'Ramirez', 'Torres', 'Diaz', 'Vargas');
BEGIN
    FOR i IN 1..3000 LOOP
        INSERT INTO CLIENTE (nombres, apellidos, documento, correo, telefono)
        VALUES (
            v_nombres(MOD(i, v_nombres.COUNT) + 1),
            v_apellidos(MOD(TRUNC(i / v_nombres.COUNT), v_apellidos.COUNT) + 1),
            'CC-' || (10000000 + i),
            'cliente.' || i || '@turismouq.edu.co',
            '31' || TRUNC(DBMS_RANDOM.VALUE(0, 9)) || LPAD(i, 7, '0')
        );
        IF MOD(i, 500) = 0 THEN
            COMMIT;
        END IF;
    END LOOP;
    COMMIT;
END;
/
PROMPT [6/9] 3.000 Clientes registrados con documentos y correos unicos.

-- ----------------------------------------------------------------------------
-- 7. POBLACION DE SERVICIOS TURISTICOS (10 Servicios Oficiales del Quindío)
-- ----------------------------------------------------------------------------
INSERT INTO SERVICIO (nombre, descripcion, precio) VALUES ('Tour del Cafe Experiencial', 'Cata guiada y recoleccion tradicional', 65000);
INSERT INTO SERVICIO (nombre, descripcion, precio) VALUES ('Cabalgata Ecologica Valle del Cocora', 'Recorrido a caballo con guia nativo', 85000);
INSERT INTO SERVICIO (nombre, descripcion, precio) VALUES ('Pasadia Parque Nacional del Cafe', 'Entrada con pasaporte multiple y teleferico', 92000);
INSERT INTO SERVICIO (nombre, descripcion, precio) VALUES ('Pasadia Panaca', 'Interaccion con animales del campo y exhibiciones', 88000);
INSERT INTO SERVICIO (nombre, descripcion, precio) VALUES ('Vuelo en Parapente Buenavista', 'Vuelo biplaza con instructor certificado', 220000);
INSERT INTO SERVICIO (nombre, descripcion, precio) VALUES ('Senderismo Bosque de Niebla', 'Caminata por la reserva natural de Salento', 45000);
INSERT INTO SERVICIO (nombre, descripcion, precio) VALUES ('Desayuno Campesino Gourmet', 'Calentado tipico, arepa de choclo y cafe especial', 28000);
INSERT INTO SERVICIO (nombre, descripcion, precio) VALUES ('Circuito Termales Santa Rosa (Transporte)', 'Traslado ida y vuelta con entrada a termales', 135000);
INSERT INTO SERVICIO (nombre, descripcion, precio) VALUES ('Sesion de Spa y Masaje Cafetero', 'Exfoliacion con cafe y chocolaterapia', 110000);
INSERT INTO SERVICIO (nombre, descripcion, precio) VALUES ('Alquiler Bicicleta Todo Terreno', 'Renta diaria con casco y kit de proteccion', 40000);
COMMIT;
PROMPT [7/9] 10 Servicios turisticos complementarios registrados.

-- ----------------------------------------------------------------------------
-- 8. POBLACION MASIVA DE RESERVAS (25.000), HABITACIONES (25.000),
--    SERVICIOS (40.000) Y PAGOS (25.000)
-- ----------------------------------------------------------------------------
DECLARE
    v_fecha_base DATE := DATE '2024-01-01';
    v_fecha_in   DATE;
    v_fecha_out  DATE;
    v_noches     NUMBER;
    v_id_hab     NUMBER;
    v_id_cli     NUMBER;
    v_tarifa     NUMBER;
    v_subtotal   NUMBER;
    v_id_res     NUMBER;
    v_serv_count NUMBER := 0;
    v_id_serv    NUMBER;
    v_precio_s   NUMBER;
    v_cant_s     NUMBER;
    v_sub_s      NUMBER;
    v_total_res  NUMBER;
    v_id_pago    NUMBER;

    -- Colecciones en memoria para inserciones por lotes
    TYPE t_num_list IS TABLE OF NUMBER;
    v_hab_ids t_num_list;
    v_serv_ids t_num_list;
    v_serv_precios t_num_list;
BEGIN
    SELECT id_habitacion BULK COLLECT INTO v_hab_ids FROM HABITACION;
    SELECT id_servicio, precio BULK COLLECT INTO v_serv_ids, v_serv_precios FROM SERVICIO;

    FOR r IN 1..25000 LOOP
        -- Distribuir fechas uniformemente en 3 años (1095 días entre 2024 y 2026)
        v_fecha_in  := v_fecha_base + TRUNC(DBMS_RANDOM.VALUE(0, 1080));
        v_noches    := TRUNC(DBMS_RANDOM.VALUE(2, 6)); -- Estadías entre 2 y 5 noches
        v_fecha_out := v_fecha_in + v_noches;

        v_id_cli := MOD(r - 1, 3000) + 1;
        v_id_hab := v_hab_ids(MOD(r - 1, v_hab_ids.COUNT) + 1);

        -- Obtener tarifa base de la habitación
        SELECT precio_noche INTO v_tarifa FROM TARIFA 
        WHERE id_habitacion = v_id_hab AND id_temporada = 1;

        v_subtotal  := v_tarifa * v_noches;
        v_total_res := v_subtotal;

        -- Inserción de la Reserva
        INSERT INTO RESERVA (fecha_creacion, fecha_check_in, fecha_check_out, total, estado, id_cliente)
        VALUES (v_fecha_in - TRUNC(DBMS_RANDOM.VALUE(5, 30)), v_fecha_in, v_fecha_out, v_total_res, 'CONFIRMADA', v_id_cli)
        RETURNING id_reserva INTO v_id_res;

        -- Inserción del detalle de habitación
        INSERT INTO RESERVA_HABITACION (id_reserva, id_habitacion, precio_unitario, subtotal)
        VALUES (v_id_res, v_id_hab, v_tarifa, v_subtotal);

        -- Inserción de servicios complementarios (40.000 consumos en total)
        -- Si r <= 15.000, agregamos 2 servicios; si r <= 25.000, 1 servicio (15.000*2 + 10.000*1 = 40.000)
        DECLARE
            v_num_servicios NUMBER := CASE WHEN r <= 15000 THEN 2 ELSE 1 END;
        BEGIN
            FOR s IN 1..v_num_servicios LOOP
                v_serv_count := v_serv_count + 1;
                v_id_serv    := v_serv_ids(MOD(v_serv_count - 1, v_serv_ids.COUNT) + 1);
                v_precio_s   := v_serv_precios(MOD(v_serv_count - 1, v_serv_precios.COUNT) + 1);
                v_cant_s     := TRUNC(DBMS_RANDOM.VALUE(1, 3));
                v_sub_s      := v_precio_s * v_cant_s;

                INSERT INTO RESERVA_SERVICIO (id_reserva, id_servicio, cantidad, precio_unitario, subtotal)
                VALUES (v_id_res, v_id_serv, v_cant_s, v_precio_s, v_sub_s);

                v_total_res := v_total_res + v_sub_s;
            END LOOP;
        END;

        -- Actualizar el total definitivo de la reserva con los servicios sumados
        UPDATE RESERVA SET total = v_total_res WHERE id_reserva = v_id_res;

        -- Inserción del Pago atómico correspondiente
        INSERT INTO PAGO (id_reserva, monto, fecha_pago, metodo_pago, estado)
        VALUES (
            v_id_res,
            v_total_res,
            v_fecha_in - 2,
            CASE MOD(r, 4) WHEN 0 THEN 'TARJETA' WHEN 1 THEN 'PSE' WHEN 2 THEN 'TRANSFERENCIA' ELSE 'EFECTIVO' END,
            'APROBADO'
        );

        -- Commit por lotes de 2.500 registros para optimizar memoria undo y redo
        IF MOD(r, 2500) = 0 THEN
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('  ... ' || r || ' reservas, habitaciones, servicios y pagos procesados.');
        END IF;
    END LOOP;
    COMMIT;
END;
/
PROMPT [8/9] 25.000 Reservas, 25.000 Habitaciones, 40.000 Servicios y 25.000 Pagos generados con éxito.

-- ----------------------------------------------------------------------------
-- 9. USUARIOS DEL SISTEMA Y ROLES (4 Perfiles Administrativos)
-- ----------------------------------------------------------------------------
INSERT INTO USUARIO_SISTEMA (username, password_hash, rol, activo)
VALUES ('recepcion_uq', '$2a$12$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBo88wP3.KWy0q', 'RECEPCION', 1);

INSERT INTO USUARIO_SISTEMA (username, password_hash, rol, activo)
VALUES ('admin_alojamiento_uq', '$2a$12$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBo88wP3.KWy0q', 'ADMIN_ALOJAMIENTO', 1);

INSERT INTO USUARIO_SISTEMA (username, password_hash, rol, activo)
VALUES ('gerente_uq', '$2a$12$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBo88wP3.KWy0q', 'GERENTE', 1);

INSERT INTO USUARIO_SISTEMA (username, password_hash, rol, activo)
VALUES ('auditor_uq', '$2a$12$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBo88wP3.KWy0q', 'AUDITOR', 1);
COMMIT;
PROMPT [9/9] 4 Usuarios del sistema configurados.

PROMPT ============================================================================
PROMPT === CARGA Y POBLACION DE VOLUMEN MINIMO COMPLETADA AL 100%               ===
PROMPT ============================================================================
