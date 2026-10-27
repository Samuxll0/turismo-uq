package com.turismouq.app.service;

import com.turismouq.app.dto.request.GuardarTarifaRequestDto;
import com.turismouq.app.dto.response.*;
import jakarta.annotation.PostConstruct;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Timestamp;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
public class AuditoriaService {

    private final JdbcTemplate jdbcTemplate;
    private volatile boolean esquemaInicializado = false;

    public AuditoriaService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @PostConstruct
    public synchronized void asegurarTablasYTrigger() {
        if (esquemaInicializado) {
            return;
        }

        // 1. Crear tabla AUDITORIA_TARIFA si no existe
        try {
            jdbcTemplate.execute("""
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
            """);
        } catch (Exception e) {
            System.err.println("Info tabla AUDITORIA_TARIFA: " + e.getMessage());
        }

        // 2. Crear tabla LOG_SENTENCIA_TARIFA si no existe
        try {
            jdbcTemplate.execute("""
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
            """);
        } catch (Exception e) {
            System.err.println("Info tabla LOG_SENTENCIA_TARIFA: " + e.getMessage());
        }

        // 3. Crear tabla PERIODO_TEMPORADA si no existe
        try {
            jdbcTemplate.execute("""
                BEGIN
                    EXECUTE IMMEDIATE '
                        CREATE TABLE TURISMO_UQ.PERIODO_TEMPORADA (
                            id_periodo      NUMBER GENERATED ALWAYS AS IDENTITY,
                            id_temporada    NUMBER NOT NULL,
                            nombre          VARCHAR2(80) NOT NULL,
                            fecha_inicio    DATE NOT NULL,
                            fecha_fin       DATE NOT NULL,
                            CONSTRAINT pk_periodo_temporada PRIMARY KEY (id_periodo),
                            CONSTRAINT fk_periodo_temporada FOREIGN KEY (id_temporada) 
                                REFERENCES TURISMO_UQ.TEMPORADA(id_temporada),
                            CONSTRAINT chk_periodo_fechas CHECK (fecha_fin >= fecha_inicio)
                        )';
                EXCEPTION
                    WHEN OTHERS THEN
                        IF SQLCODE = -955 THEN NULL; ELSE RAISE; END IF;
                END;
            """);
        } catch (Exception e) {
            System.err.println("Info tabla PERIODO_TEMPORADA: " + e.getMessage());
        }

        // 4. Poblar PERIODO_TEMPORADA con ventanas de alta demanda si está vacía
        try {
            jdbcTemplate.execute("""
                BEGIN
                    INSERT INTO TURISMO_UQ.PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
                    SELECT 2, 'Semana Santa 2025', DATE '2025-04-12', DATE '2025-04-20' FROM DUAL
                    WHERE NOT EXISTS (SELECT 1 FROM TURISMO_UQ.PERIODO_TEMPORADA WHERE nombre = 'Semana Santa 2025');

                    INSERT INTO TURISMO_UQ.PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
                    SELECT 2, 'Mitad de Anio 2025', DATE '2025-06-14', DATE '2025-07-19' FROM DUAL
                    WHERE NOT EXISTS (SELECT 1 FROM TURISMO_UQ.PERIODO_TEMPORADA WHERE nombre = 'Mitad de Anio 2025');

                    INSERT INTO TURISMO_UQ.PERIODO_TEMPORADA (id_temporada, nombre, fecha_inicio, fecha_fin)
                    SELECT 2, 'Fin de Anio 2025', DATE '2025-12-15', DATE '2026-01-15' FROM DUAL
                    WHERE NOT EXISTS (SELECT 1 FROM TURISMO_UQ.PERIODO_TEMPORADA WHERE nombre = 'Fin de Anio 2025');
                    COMMIT;
                EXCEPTION
                    WHEN OTHERS THEN NULL;
                END;
            """);
        } catch (Exception e) {
            System.err.println("Info datos PERIODO_TEMPORADA: " + e.getMessage());
        }

        // 5. Compilar Disparador Compuesto TRG_AUDITORIA_TARIFA sobre TARIFA
        try {
            jdbcTemplate.execute("""
                CREATE OR REPLACE TRIGGER TURISMO_UQ.TRG_AUDITORIA_TARIFA
                FOR INSERT OR UPDATE OR DELETE ON TURISMO_UQ.TARIFA
                COMPOUND TRIGGER

                    g_usuario         VARCHAR2(60);
                    g_filas_afectadas NUMBER := 0;
                    g_accion          VARCHAR2(10);

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
            """);
        } catch (Exception e) {
            System.err.println("Info disparador TRG_AUDITORIA_TARIFA: " + e.getMessage());
        }

        esquemaInicializado = true;
    }

    public List<AuditoriaFilaDto> obtenerAuditoriaFilas(int limite) {
        asegurarTablasYTrigger();

        String sql = """
            SELECT 
                a.id_auditoria,
                a.usuario,
                a.fecha,
                a.id_tarifa,
                a.id_habitacion,
                NVL(h.numero_nombre, 'N/A') AS numero_habitacion,
                NVL(al.nombre, 'Sin Alojamiento') AS nombre_alojamiento,
                NVL(t.nombre, 'General') AS nombre_temporada,
                NVL(a.precio_anterior, 0) AS precio_anterior,
                NVL(a.precio_nuevo, 0) AS precio_nuevo,
                (NVL(a.precio_nuevo, 0) - NVL(a.precio_anterior, 0)) AS variacion,
                a.accion
            FROM TURISMO_UQ.AUDITORIA_TARIFA a
            LEFT JOIN TURISMO_UQ.HABITACION h ON a.id_habitacion = h.id_habitacion
            LEFT JOIN TURISMO_UQ.ALOJAMIENTO al ON h.id_alojamiento = al.id_alojamiento
            LEFT JOIN TURISMO_UQ.TEMPORADA t ON a.id_temporada = t.id_temporada
            ORDER BY a.id_auditoria DESC
            FETCH FIRST ? ROWS ONLY
        """;

        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");

        try {
            return jdbcTemplate.query(sql, (rs, rowNum) -> {
                Timestamp ts = rs.getTimestamp("fecha");
                String fechaStr = ts != null ? sdf.format(ts) : "N/A";

                return new AuditoriaFilaDto(
                        rs.getLong("id_auditoria"),
                        rs.getString("usuario"),
                        fechaStr,
                        rs.getLong("id_tarifa"),
                        rs.getLong("id_habitacion"),
                        rs.getString("numero_habitacion"),
                        rs.getString("nombre_alojamiento"),
                        rs.getString("nombre_temporada"),
                        rs.getBigDecimal("precio_anterior"),
                        rs.getBigDecimal("precio_nuevo"),
                        rs.getBigDecimal("variacion"),
                        rs.getString("accion")
                );
            }, limite);
        } catch (Exception e) {
            System.err.println("Error consultando AUDITORIA_TARIFA: " + e.getMessage());
            return new ArrayList<>();
        }
    }

    public List<AuditoriaSentenciaDto> obtenerAuditoriaSentencias(int limite) {
        asegurarTablasYTrigger();

        String sql = """
            SELECT 
                id_log,
                usuario,
                fecha,
                accion,
                total_filas
            FROM TURISMO_UQ.LOG_SENTENCIA_TARIFA
            ORDER BY id_log DESC
            FETCH FIRST ? ROWS ONLY
        """;

        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");

        try {
            return jdbcTemplate.query(sql, (rs, rowNum) -> {
                Timestamp ts = rs.getTimestamp("fecha");
                String fechaStr = ts != null ? sdf.format(ts) : "N/A";

                return new AuditoriaSentenciaDto(
                        rs.getLong("id_log"),
                        rs.getString("usuario"),
                        fechaStr,
                        rs.getString("accion"),
                        rs.getLong("total_filas")
                );
            }, limite);
        } catch (Exception e) {
            System.err.println("Error consultando LOG_SENTENCIA_TARIFA: " + e.getMessage());
            return new ArrayList<>();
        }
    }

    public List<TarifaDetalleDto> obtenerTarifasDetalle(Long idAlojamiento, String busqueda) {
        asegurarTablasYTrigger();

        StringBuilder sql = new StringBuilder("""
            SELECT 
                h.id_habitacion,
                h.numero_nombre,
                h.capacidad,
                h.tipo_cama,
                al.id_alojamiento,
                al.nombre AS nombre_alojamiento,
                m.nombre AS nombre_municipio,
                MAX(CASE WHEN t.id_temporada = 1 THEN t.id_tarifa END) AS id_tarifa_baja,
                NVL(MAX(CASE WHEN t.id_temporada = 1 THEN t.precio_noche END), 0) AS precio_baja,
                MAX(CASE WHEN t.id_temporada = 2 THEN t.id_tarifa END) AS id_tarifa_alta,
                NVL(MAX(CASE WHEN t.id_temporada = 2 THEN t.precio_noche END), 0) AS precio_alta
            FROM TURISMO_UQ.HABITACION h
            JOIN TURISMO_UQ.ALOJAMIENTO al ON h.id_alojamiento = al.id_alojamiento
            JOIN TURISMO_UQ.MUNICIPIO m ON al.id_municipio = m.id_municipio
            LEFT JOIN TURISMO_UQ.TARIFA t ON h.id_habitacion = t.id_habitacion
            WHERE 1=1
        """);

        List<Object> params = new ArrayList<>();

        if (idAlojamiento != null) {
            sql.append(" AND al.id_alojamiento = ?");
            params.add(idAlojamiento);
        }

        if (busqueda != null && !busqueda.isBlank()) {
            sql.append(" AND (LOWER(al.nombre) LIKE ? OR LOWER(h.numero_nombre) LIKE ? OR LOWER(m.nombre) LIKE ?)");
            String queryLike = "%" + busqueda.trim().toLowerCase() + "%";
            params.add(queryLike);
            params.add(queryLike);
            params.add(queryLike);
        }

        sql.append(" GROUP BY h.id_habitacion, h.numero_nombre, h.capacidad, h.tipo_cama, al.id_alojamiento, al.nombre, m.nombre");
        sql.append(" ORDER BY al.nombre ASC, h.numero_nombre ASC");

        try {
            return jdbcTemplate.query(sql.toString(), (rs, rowNum) -> {
                BigDecimal baja = rs.getBigDecimal("precio_baja");
                BigDecimal alta = rs.getBigDecimal("precio_alta");

                if (baja == null || baja.compareTo(BigDecimal.ZERO) <= 0) {
                    baja = BigDecimal.valueOf(180000);
                }
                if (alta == null || alta.compareTo(BigDecimal.ZERO) <= 0) {
                    long altaCalc = Math.round((baja.doubleValue() * 1.40) / 1000.0) * 1000;
                    alta = BigDecimal.valueOf(altaCalc);
                }
                BigDecimal recargo = alta.subtract(baja);
                double pct = (baja.compareTo(BigDecimal.ZERO) > 0)
                        ? (recargo.doubleValue() / baja.doubleValue()) * 100.0
                        : 40.0;

                return new TarifaDetalleDto(
                        rs.getLong("id_habitacion"),
                        rs.getString("numero_nombre"),
                        rs.getInt("capacidad"),
                        rs.getString("tipo_cama"),
                        rs.getLong("id_alojamiento"),
                        rs.getString("nombre_alojamiento"),
                        rs.getString("nombre_municipio"),
                        rs.getLong("id_tarifa_baja"),
                        baja,
                        rs.getLong("id_tarifa_alta"),
                        alta,
                        recargo,
                        Math.round(pct * 10.0) / 10.0
                );
            }, params.toArray());
        } catch (Exception e) {
            System.err.println("Error consultando tarifas: " + e.getMessage());
            return new ArrayList<>();
        }
    }

    public List<PeriodoTemporadaDto> obtenerPeriodosTemporada() {
        asegurarTablasYTrigger();

        String sql = """
            SELECT 
                p.id_periodo,
                p.id_temporada,
                p.nombre,
                TO_CHAR(p.fecha_inicio, 'YYYY-MM-DD') AS fecha_inicio,
                TO_CHAR(p.fecha_fin, 'YYYY-MM-DD') AS fecha_fin,
                ROUND(p.fecha_fin - p.fecha_inicio) AS dias_duracion
            FROM TURISMO_UQ.PERIODO_TEMPORADA p
            ORDER BY p.fecha_inicio ASC
        """;

        try {
            return jdbcTemplate.query(sql, (rs, rowNum) -> new PeriodoTemporadaDto(
                    rs.getLong("id_periodo"),
                    rs.getLong("id_temporada"),
                    rs.getString("nombre"),
                    rs.getString("fecha_inicio"),
                    rs.getString("fecha_fin"),
                    rs.getLong("dias_duracion")
            ));
        } catch (Exception e) {
            System.err.println("Error consultando PERIODO_TEMPORADA: " + e.getMessage());
            return new ArrayList<>();
        }
    }

    @Transactional
    public TarifaDetalleDto guardarOActualizarTarifa(GuardarTarifaRequestDto request) {
        asegurarTablasYTrigger();

        if (request.idHabitacion() == null) {
            throw new IllegalArgumentException("El ID de la habitación es obligatorio");
        }
        if (request.precioBaja() == null || request.precioBaja().compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("El precio de temporada baja debe ser mayor a cero");
        }

        final BigDecimal precioBaja = request.precioBaja().setScale(0, RoundingMode.HALF_UP);
        final BigDecimal precioAlta = (request.precioAlta() == null || request.precioAlta().compareTo(BigDecimal.ZERO) <= 0)
                ? BigDecimal.valueOf(Math.round((precioBaja.doubleValue() * 1.40) / 1000.0) * 1000)
                : request.precioAlta().setScale(0, RoundingMode.HALF_UP);

        // 1. Persistir Temporada Baja (id_temporada = 1) - Dispara TRG_AUDITORIA_TARIFA
        Integer countBaja = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM TURISMO_UQ.TARIFA WHERE id_habitacion = ? AND id_temporada = 1",
                Integer.class, request.idHabitacion());

        if (countBaja != null && countBaja > 0) {
            jdbcTemplate.update(
                    "UPDATE TURISMO_UQ.TARIFA SET precio_noche = ? WHERE id_habitacion = ? AND id_temporada = 1",
                    precioBaja, request.idHabitacion());
        } else {
            jdbcTemplate.update(
                    "INSERT INTO TURISMO_UQ.TARIFA (id_habitacion, id_temporada, precio_noche) VALUES (?, 1, ?)",
                    request.idHabitacion(), precioBaja);
        }

        // 2. Persistir Temporada Alta (id_temporada = 2) - Dispara TRG_AUDITORIA_TARIFA
        Integer countAlta = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM TURISMO_UQ.TARIFA WHERE id_habitacion = ? AND id_temporada = 2",
                Integer.class, request.idHabitacion());

        if (countAlta != null && countAlta > 0) {
            jdbcTemplate.update(
                    "UPDATE TURISMO_UQ.TARIFA SET precio_noche = ? WHERE id_habitacion = ? AND id_temporada = 2",
                    precioAlta, request.idHabitacion());
        } else {
            jdbcTemplate.update(
                    "INSERT INTO TURISMO_UQ.TARIFA (id_habitacion, id_temporada, precio_noche) VALUES (?, 2, ?)",
                    request.idHabitacion(), precioAlta);
        }

        List<TarifaDetalleDto> list = obtenerTarifasDetalle(null, null);
        return list.stream()
                .filter(t -> t != null && request.idHabitacion().equals(t.idHabitacion()))
                .findFirst()
                .orElseGet(() -> new TarifaDetalleDto(
                        request.idHabitacion(),
                        "Habitación #" + request.idHabitacion(),
                        2,
                        "Cama Estándar",
                        1L,
                        "Alojamiento",
                        "Quindío",
                        1L,
                        precioBaja,
                        2L,
                        precioAlta,
                        precioAlta.subtract(precioBaja),
                        40.0
                ));
    }

    public AuditoriaResumenDto obtenerResumen() {
        asegurarTablasYTrigger();

        Long totalFilas = 0L;
        Long totalSentencias = 0L;

        try {
            totalFilas = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM TURISMO_UQ.AUDITORIA_TARIFA", Long.class);
        } catch (Exception e) {
            System.err.println("No se pudo contar AUDITORIA_TARIFA: " + e.getMessage());
        }

        try {
            totalSentencias = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM TURISMO_UQ.LOG_SENTENCIA_TARIFA", Long.class);
        } catch (Exception e) {
            System.err.println("No se pudo contar LOG_SENTENCIA_TARIFA: " + e.getMessage());
        }

        String estadoTrigger = "ENABLED";
        String tipoTrigger = "COMPOUND";
        try {
            List<Map<String, Object>> rows = jdbcTemplate.queryForList(
                    "SELECT status, trigger_type FROM USER_TRIGGERS WHERE trigger_name = 'TRG_AUDITORIA_TARIFA'");
            if (!rows.isEmpty()) {
                estadoTrigger = (String) rows.get(0).get("STATUS");
                tipoTrigger = (String) rows.get(0).get("TRIGGER_TYPE");
            }
        } catch (Exception ignored) {}

        List<AuditoriaFilaDto> ultimasFilas = obtenerAuditoriaFilas(50);
        List<AuditoriaSentenciaDto> ultimasSentencias = obtenerAuditoriaSentencias(50);

        String ultimoUsuario = "TURISMO_UQ";
        String ultimaFecha = "Sin registros recientes";
        if (!ultimasSentencias.isEmpty()) {
            ultimoUsuario = ultimasSentencias.get(0).usuario();
            ultimaFecha = ultimasSentencias.get(0).fecha();
        } else if (!ultimasFilas.isEmpty()) {
            ultimoUsuario = ultimasFilas.get(0).usuario();
            ultimaFecha = ultimasFilas.get(0).fecha();
        }

        return new AuditoriaResumenDto(
                totalFilas != null ? totalFilas : 0L,
                totalSentencias != null ? totalSentencias : 0L,
                "TRG_AUDITORIA_TARIFA",
                tipoTrigger != null ? tipoTrigger : "COMPOUND",
                estadoTrigger != null ? estadoTrigger : "ENABLED",
                ultimoUsuario,
                ultimaFecha,
                ultimasFilas,
                ultimasSentencias
        );
    }

    @Transactional
    public int simularAjusteTarifas(Long idHabitacion, Long idTemporada, Double porcentaje) {
        asegurarTablasYTrigger();

        if (porcentaje == null || porcentaje == 0.0) {
            porcentaje = 5.0; // default +5%
        }
        double factor = 1.0 + (porcentaje / 100.0);

        StringBuilder sql = new StringBuilder("UPDATE TURISMO_UQ.TARIFA SET precio_noche = ROUND(precio_noche * ?, -2) WHERE 1=1");
        List<Object> params = new ArrayList<>();
        params.add(factor);

        if (idHabitacion != null) {
            sql.append(" AND id_habitacion = ?");
            params.add(idHabitacion);
        }
        if (idTemporada != null) {
            sql.append(" AND id_temporada = ?");
            params.add(idTemporada);
        }

        return jdbcTemplate.update(sql.toString(), params.toArray());
    }

    @Transactional
    public void limpiarAuditoria() {
        asegurarTablasYTrigger();
        try {
            jdbcTemplate.execute("DELETE FROM TURISMO_UQ.AUDITORIA_TARIFA");
        } catch (Exception ignored) {}
        try {
            jdbcTemplate.execute("DELETE FROM TURISMO_UQ.LOG_SENTENCIA_TARIFA");
        } catch (Exception ignored) {}
    }
}
