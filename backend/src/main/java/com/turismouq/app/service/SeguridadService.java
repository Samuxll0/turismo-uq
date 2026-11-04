package com.turismouq.app.service;

import com.turismouq.app.dto.response.PerfilLimiteDto;
import com.turismouq.app.dto.response.RolSeguridadDto;
import com.turismouq.app.dto.response.VistaRecepcionItemDto;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class SeguridadService {

    private final JdbcTemplate jdbcTemplate;

    public SeguridadService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * Retorna la matriz de los 4 roles diferenciados (ROL_RECEPCION, ROL_ADMIN_ALOJAMIENTO,
     * ROL_GERENTE y ROL_AUDITOR) y la política de aislamiento por vistas.
     */
    public List<RolSeguridadDto> obtenerRolesMatriz() {
        String sql = """
            SELECT
                id_rol,
                nombre_rol,
                titulo_rol,
                acceso_tablas_base,
                objetos_permitidos,
                privilegios_dml,
                aislamiento_vistas,
                justificacion
            FROM TURISMO_UQ.CATALOGO_SEGURIDAD_ROLES
            ORDER BY id_rol ASC
        """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new RolSeguridadDto(
                rs.getLong("ID_ROL"),
                rs.getString("NOMBRE_ROL"),
                rs.getString("TITULO_ROL"),
                rs.getString("ACCESO_TABLAS_BASE"),
                rs.getString("OBJETOS_PERMITIDOS"),
                rs.getString("PRIVILEGIOS_DML"),
                "S".equalsIgnoreCase(rs.getString("AISLAMIENTO_VISTAS")),
                rs.getString("JUSTIFICACION")
        ));
    }

    /**
     * Retorna los límites de sesión y conexión configurados en PERFIL_TURISMO_OPERATIVO.
     */
    public List<PerfilLimiteDto> obtenerPerfilLimites() {
        String sql = """
            SELECT
                id_parametro,
                nombre_perfil,
                recurso,
                valor_limite,
                unidad,
                proposito
            FROM TURISMO_UQ.CATALOGO_PERFIL_LIMITES
            ORDER BY id_parametro ASC
        """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new PerfilLimiteDto(
                rs.getLong("ID_PARAMETRO"),
                rs.getString("NOMBRE_PERFIL"),
                rs.getString("RECURSO"),
                rs.getString("VALOR_LIMITE"),
                rs.getString("UNIDAD"),
                rs.getString("PROPOSITO")
        ));
    }

    /**
     * Consulta la vista exclusiva VW_RECEPCION_RESERVAS en unión con VW_RECEPCION_CHECKIN,
     * demostrando la operación de recepción sin acceso a tablas directas.
     */
    public List<VistaRecepcionItemDto> consultarVistaRecepcion(int limite) {
        int maxFilas = (limite > 0 && limite <= 50) ? limite : 12;
        String sql = """
            SELECT
                vr.id_reserva,
                vr.fecha_check_in,
                vr.fecha_check_out,
                vr.noches_estadia,
                vr.estado_reserva,
                vr.valor_total,
                vr.documento_cliente,
                vr.nombre_huesped,
                vr.habitacion,
                vr.alojamiento,
                vr.municipio,
                NVL(vc.estado_pago, 'APROBADO') AS estado_pago,
                NVL(vc.medio_pago, 'TARJETA') AS medio_pago
            FROM TURISMO_UQ.VW_RECEPCION_RESERVAS vr
            LEFT JOIN TURISMO_UQ.VW_RECEPCION_CHECKIN vc ON vr.id_reserva = vc.id_reserva
            ORDER BY vr.id_reserva DESC
            FETCH FIRST ? ROWS ONLY
        """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new VistaRecepcionItemDto(
                rs.getLong("ID_RESERVA"),
                rs.getDate("FECHA_CHECK_IN") != null ? rs.getDate("FECHA_CHECK_IN").toLocalDate() : null,
                rs.getDate("FECHA_CHECK_OUT") != null ? rs.getDate("FECHA_CHECK_OUT").toLocalDate() : null,
                rs.getInt("NOCHES_ESTADIA"),
                rs.getString("ESTADO_RESERVA"),
                rs.getBigDecimal("VALOR_TOTAL"),
                rs.getString("DOCUMENTO_CLIENTE"),
                rs.getString("NOMBRE_HUESPED"),
                rs.getString("HABITACION"),
                rs.getString("ALOJAMIENTO"),
                rs.getString("MUNICIPIO"),
                rs.getString("ESTADO_PAGO"),
                rs.getString("MEDIO_PAGO")
        ), maxFilas);
    }
}
