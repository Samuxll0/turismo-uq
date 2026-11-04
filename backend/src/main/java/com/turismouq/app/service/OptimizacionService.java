package com.turismouq.app.service;

import com.turismouq.app.dto.response.PlanEjecucionIndiceDto;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class OptimizacionService {

    private final JdbcTemplate jdbcTemplate;

    public OptimizacionService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * Consulta los planes de ejecución Antes y Después medidos por el Optimizador Basado en Costos (CBO)
     * sobre las 25.000 reservas y 40.000 servicios, incluyendo el Caso Negativo obligatorio.
     */
    public List<PlanEjecucionIndiceDto> obtenerPlanesEjecucion() {
        String sql = """
            SELECT
                id_caso,
                codigo_consulta,
                titulo,
                tipo_indice,
                nombre_indice,
                ddl_indice,
                sql_consulta,
                operacion_antes,
                costo_antes,
                cardinalidad_antes,
                bytes_antes,
                tiempo_ms_antes,
                plan_texto_antes,
                operacion_despues,
                costo_despues,
                cardinalidad_despues,
                bytes_despues,
                tiempo_ms_despues,
                plan_texto_despues,
                reduccion_costo_pct,
                es_caso_negativo,
                explicacion_tecnica
            FROM TURISMO_UQ.AUDITORIA_PLANES_INDICES
            ORDER BY id_caso ASC
        """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new PlanEjecucionIndiceDto(
                rs.getLong("ID_CASO"),
                rs.getString("CODIGO_CONSULTA"),
                rs.getString("TITULO"),
                rs.getString("TIPO_INDICE"),
                rs.getString("NOMBRE_INDICE"),
                rs.getString("DDL_INDICE"),
                rs.getString("SQL_CONSULTA"),
                rs.getString("OPERACION_ANTES"),
                rs.getLong("COSTO_ANTES"),
                rs.getLong("CARDINALIDAD_ANTES"),
                rs.getLong("BYTES_ANTES"),
                rs.getBigDecimal("TIEMPO_MS_ANTES"),
                rs.getString("PLAN_TEXTO_ANTES"),
                rs.getString("OPERACION_DESPUES"),
                rs.getLong("COSTO_DESPUES"),
                rs.getLong("CARDINALIDAD_DESPUES"),
                rs.getLong("BYTES_DESPUES"),
                rs.getBigDecimal("TIEMPO_MS_DESPUES"),
                rs.getString("PLAN_TEXTO_DESPUES"),
                rs.getBigDecimal("REDUCCION_COSTO_PCT"),
                "S".equalsIgnoreCase(rs.getString("ES_CASO_NEGATIVO")),
                rs.getString("EXPLICACION_TECNICA")
        ));
    }
}
