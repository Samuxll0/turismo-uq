package com.turismouq.app.repository;

import com.turismouq.app.dto.response.AnaliticaJerarquiaDto;
import com.turismouq.app.dto.response.AnaliticaOcupacionDto;
import com.turismouq.app.dto.response.AnaliticaTopAlojamientoDto;
import com.turismouq.app.dto.response.AnaliticaVariacionDto;
import com.turismouq.app.dto.response.AnaliticaRangoFechasDto;
import com.turismouq.app.dto.response.AnaliticaMaterializadaDto;
import com.turismouq.app.dto.response.AnaliticaUnpivotDto;
import com.turismouq.app.dto.response.AnaliticaClienteClvDto;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public class AnaliticaRepository {

    private final JdbcTemplate jdbcTemplate;

    public AnaliticaRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<AnaliticaOcupacionDto> getOcupacionMensualPivot() {
        String sql = """
            SELECT *
            FROM (
                SELECT 
                    m.nombre AS municipio,
                    EXTRACT(MONTH FROM r.fecha_check_in) AS mes,
                    r.id_reserva
                FROM RESERVA r
                JOIN RESERVA_HABITACION rh ON r.id_reserva = rh.id_reserva
                JOIN HABITACION h          ON rh.id_habitacion = h.id_habitacion
                JOIN ALOJAMIENTO a         ON h.id_alojamiento = a.id_alojamiento
                JOIN MUNICIPIO m           ON a.id_municipio = m.id_municipio
                WHERE r.fecha_check_in >= DATE '2025-01-01'
                  AND r.fecha_check_in <  DATE '2026-01-01'
            )
            PIVOT (
                COUNT(id_reserva)
                FOR mes IN (
                    1 AS ENE, 2 AS FEB, 3 AS MAR,  4 AS ABR,
                    5 AS MAY, 6 AS JUN, 7 AS JUL,  8 AS AGO,
                    9 AS SEP, 10 AS OCT, 11 AS NOV, 12 AS DIC
                )
            )
            ORDER BY municipio
        """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new AnaliticaOcupacionDto(
                rs.getString("MUNICIPIO"),
                rs.getLong("ENE"), rs.getLong("FEB"), rs.getLong("MAR"), rs.getLong("ABR"),
                rs.getLong("MAY"), rs.getLong("JUN"), rs.getLong("JUL"), rs.getLong("AGO"),
                rs.getLong("SEP"), rs.getLong("OCT"), rs.getLong("NOV"), rs.getLong("DIC")
        ));
    }

    public List<AnaliticaJerarquiaDto> getIngresosJerarquiaRollup() {
        String sql = """
            SELECT 
                CASE 
                    WHEN GROUPING(m.nombre) = 1 THEN '>>> TOTAL DEPARTAMENTAL <<<'
                    ELSE m.nombre 
                END AS municipio,
                CASE 
                    WHEN GROUPING(ta.nombre) = 1 AND GROUPING(m.nombre) = 0 THEN '-- Subtotal Municipio --'
                    WHEN GROUPING(ta.nombre) = 1 THEN 'N/A'
                    ELSE ta.nombre 
                END AS tipo_alojamiento,
                CASE 
                    WHEN GROUPING(t.nombre) = 1 AND GROUPING(ta.nombre) = 0 THEN '-- Subtotal Tipo --'
                    WHEN GROUPING(t.nombre) = 1 THEN 'N/A'
                    ELSE t.nombre 
                END AS temporada,
                COUNT(r.id_reserva) AS cantidad_reservas,
                SUM(r.total) AS ingresos_totales,
                GROUPING(m.nombre) AS g_mun,
                GROUPING(ta.nombre) AS g_tipo,
                GROUPING(t.nombre) AS g_temp
            FROM MUNICIPIO m
            JOIN ALOJAMIENTO a         ON m.id_municipio = a.id_municipio
            JOIN TIPO_ALOJAMIENTO ta   ON a.id_tipo_alojamiento = ta.id_tipo_alojamiento
            JOIN HABITACION h          ON a.id_alojamiento = h.id_alojamiento
            JOIN TARIFA tf             ON h.id_habitacion = tf.id_habitacion
            JOIN TEMPORADA t           ON tf.id_temporada = t.id_temporada
            JOIN RESERVA_HABITACION rh ON h.id_habitacion = rh.id_habitacion
            JOIN RESERVA r             ON rh.id_reserva = r.id_reserva
            WHERE r.fecha_check_in >= DATE '2025-01-01' AND r.fecha_check_in < DATE '2026-01-01'
            GROUP BY ROLLUP(m.nombre, ta.nombre, t.nombre)
            ORDER BY GROUPING(m.nombre), m.nombre, GROUPING(ta.nombre), ta.nombre
        """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new AnaliticaJerarquiaDto(
                rs.getString("MUNICIPIO"),
                rs.getString("TIPO_ALOJAMIENTO"),
                rs.getString("TEMPORADA"),
                rs.getLong("CANTIDAD_RESERVAS"),
                rs.getBigDecimal("INGRESOS_TOTALES"),
                rs.getInt("G_MUN"),
                rs.getInt("G_TIPO"),
                rs.getInt("G_TEMP")
        ));
    }

    public List<AnaliticaTopAlojamientoDto> getTopAlojamientosRanking() {
        String sql = """
            WITH ranking_alojamientos AS (
                SELECT 
                    m.nombre AS municipio,
                    a.nombre AS alojamiento,
                    SUM(r.total) AS ingresos_alojamiento,
                    DENSE_RANK() OVER (
                        PARTITION BY m.id_municipio 
                        ORDER BY SUM(r.total) DESC
                    ) AS posicion_ranking
                FROM MUNICIPIO m
                JOIN ALOJAMIENTO a         ON m.id_municipio = a.id_municipio
                JOIN HABITACION h          ON a.id_alojamiento = h.id_alojamiento
                JOIN RESERVA_HABITACION rh ON h.id_habitacion = rh.id_habitacion
                JOIN RESERVA r             ON rh.id_reserva = r.id_reserva
                GROUP BY m.id_municipio, m.nombre, a.id_alojamiento, a.nombre
            )
            SELECT 
                municipio,
                posicion_ranking,
                alojamiento,
                ingresos_alojamiento
            FROM ranking_alojamientos
            WHERE posicion_ranking <= 3
            ORDER BY municipio, posicion_ranking
        """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new AnaliticaTopAlojamientoDto(
                rs.getString("MUNICIPIO"),
                rs.getInt("POSICION_RANKING"),
                rs.getString("ALOJAMIENTO"),
                rs.getBigDecimal("INGRESOS_ALOJAMIENTO")
        ));
    }

    public List<AnaliticaVariacionDto> getVariacionMesLag() {
        String sql = """
            WITH ventas_mensuales AS (
                SELECT 
                    TRUNC(r.fecha_check_in, 'MM') AS periodo_mes,
                    SUM(r.total) AS facturacion_actual
                FROM RESERVA r
                GROUP BY TRUNC(r.fecha_check_in, 'MM')
            )
            SELECT 
                TO_CHAR(periodo_mes, 'YYYY-MM') AS anio_mes,
                facturacion_actual,
                LAG(facturacion_actual, 1) OVER (ORDER BY periodo_mes) AS facturacion_mes_anterior,
                ROUND(
                    facturacion_actual - LAG(facturacion_actual, 1) OVER (ORDER BY periodo_mes), 
                    2
                ) AS diferencia_neta,
                ROUND(
                    ((facturacion_actual - LAG(facturacion_actual, 1) OVER (ORDER BY periodo_mes)) 
                     / NULLIF(LAG(facturacion_actual, 1) OVER (ORDER BY periodo_mes), 0)) * 100, 
                    2
                ) AS porcentaje_crecimiento
            FROM ventas_mensuales
            ORDER BY periodo_mes
        """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new AnaliticaVariacionDto(
                rs.getString("ANIO_MES"),
                rs.getBigDecimal("FACTURACION_ACTUAL"),
                rs.getBigDecimal("FACTURACION_MES_ANTERIOR"),
                rs.getBigDecimal("DIFERENCIA_NETA"),
                rs.getBigDecimal("PORCENTAJE_CRECIMIENTO")
        ));
    }

    /**
     * Consulta 5: Consulta parametrizada con variables de enlace (Bind Variables).
     */
    public List<AnaliticaRangoFechasDto> getRangoFechasBind(String fechaInicio, String fechaFin) {
        String fIni = (fechaInicio != null && !fechaInicio.isBlank()) ? fechaInicio.trim() : "2025-06-01";
        String fFin = (fechaFin != null && !fechaFin.isBlank()) ? fechaFin.trim() : "2025-08-31";

        String sql = """
            SELECT 
                m.nombre AS municipio,
                COUNT(r.id_reserva) AS reservas_periodo,
                NVL(SUM(r.total), 0) AS total_recaudado,
                ROUND(NVL(AVG(r.total), 0), 2) AS ticket_promedio
            FROM MUNICIPIO m
            JOIN ALOJAMIENTO a         ON m.id_municipio = a.id_municipio
            JOIN HABITACION h          ON a.id_alojamiento = h.id_alojamiento
            JOIN RESERVA_HABITACION rh ON h.id_habitacion = rh.id_habitacion
            JOIN RESERVA r             ON rh.id_reserva = r.id_reserva
            WHERE r.fecha_check_in >= TO_DATE(?, 'YYYY-MM-DD')
              AND r.fecha_check_in <= TO_DATE(?, 'YYYY-MM-DD')
            GROUP BY m.nombre
            ORDER BY total_recaudado DESC
        """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new AnaliticaRangoFechasDto(
                rs.getString("MUNICIPIO"),
                rs.getLong("RESERVAS_PERIODO"),
                rs.getBigDecimal("TOTAL_RECAUDADO"),
                rs.getBigDecimal("TICKET_PROMEDIO")
        ), fIni, fFin);
    }

    /**
     * Consulta 6: Vista Materializada de Ocupación Mensual (MV_OCUPACION_MENSUAL).
     */
    public List<AnaliticaMaterializadaDto> getVistaMaterializada(String anioMes) {
        String mesFiltro = (anioMes != null && !anioMes.isBlank() && !anioMes.equalsIgnoreCase("TODOS")) ? anioMes.trim() : "2025-07";

        String sql = """
            SELECT 
                id_municipio,
                municipio,
                tipo_alojamiento,
                anio_mes,
                total_reservas,
                total_habitaciones_ocupadas,
                facturacion_acumulada
            FROM MV_OCUPACION_MENSUAL
            WHERE anio_mes = ?
            ORDER BY facturacion_acumulada DESC
        """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new AnaliticaMaterializadaDto(
                rs.getLong("ID_MUNICIPIO"),
                rs.getString("MUNICIPIO"),
                rs.getString("TIPO_ALOJAMIENTO"),
                rs.getString("ANIO_MES"),
                rs.getLong("TOTAL_RESERVAS"),
                rs.getLong("TOTAL_HABITACIONES_OCUPADAS"),
                rs.getBigDecimal("FACTURACION_ACUMULADA")
        ), mesFiltro);
    }

    /**
     * Consulta 7: Despivotado de métricas (UNPIVOT).
     */
    public List<AnaliticaUnpivotDto> getDespivotadoMetricas(String mes) {
        String mesFiltro = (mes != null && !mes.isBlank()) ? mes.trim() : "2025-01";

        String sql = """
            WITH resumen_componentes AS (
                SELECT 
                    r.id_reserva,
                    TO_CHAR(r.fecha_check_in, 'YYYY-MM') AS mes,
                    SUM(rh.subtotal) AS ingreso_hospedaje,
                    NVL(SUM(rs.subtotal), 0) AS ingreso_servicios
                FROM RESERVA r
                JOIN RESERVA_HABITACION rh ON r.id_reserva = rh.id_reserva
                LEFT JOIN RESERVA_SERVICIO rs ON r.id_reserva = rs.id_reserva
                WHERE r.fecha_check_in >= TO_DATE(? || '-01', 'YYYY-MM-DD')
                  AND r.fecha_check_in < ADD_MONTHS(TO_DATE(? || '-01', 'YYYY-MM-DD'), 1)
                GROUP BY r.id_reserva, TO_CHAR(r.fecha_check_in, 'YYYY-MM')
            )
            SELECT 
                id_reserva,
                mes,
                concepto_gasto,
                monto
            FROM resumen_componentes
            UNPIVOT (
                monto FOR concepto_gasto IN (
                    ingreso_hospedaje AS 'HOSPEDAJE_HABITACION',
                    ingreso_servicios AS 'ACTIVIDADES_SERVICIOS'
                )
            )
            WHERE ROWNUM <= 50
        """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new AnaliticaUnpivotDto(
                rs.getLong("ID_RESERVA"),
                rs.getString("MES"),
                rs.getString("CONCEPTO_GASTO"),
                rs.getBigDecimal("MONTO")
        ), mesFiltro, mesFiltro);
    }

    /**
     * Consulta 8: Top 10 Clientes por Valor de Vida (CLV) con FETCH FIRST 10 ROWS ONLY.
     */
    public List<AnaliticaClienteClvDto> getTopClientesClv() {
        String sql = """
            WITH metricas_cliente AS (
                SELECT 
                    c.id_cliente,
                    c.nombres || ' ' || c.apellidos AS nombre_completo,
                    COUNT(DISTINCT r.id_reserva) AS total_estadias,
                    SUM(r.total) AS gasto_historico_total,
                    COUNT(rs.id_servicio) AS total_servicios_contratados,
                    ROUND(AVG(r.total), 2) AS ticket_promedio
                FROM CLIENTE c
                JOIN RESERVA r ON c.id_cliente = r.id_cliente
                LEFT JOIN RESERVA_SERVICIO rs ON r.id_reserva = rs.id_reserva
                GROUP BY c.id_cliente, c.nombres, c.apellidos
            ),
            total_plataforma AS (
                SELECT SUM(total) AS gran_total FROM RESERVA
            )
            SELECT 
                mc.id_cliente,
                mc.nombre_completo,
                mc.total_estadias,
                mc.total_servicios_contratados,
                mc.gasto_historico_total,
                mc.ticket_promedio,
                ROUND((mc.gasto_historico_total / tp.gran_total) * 100, 4) AS pct_facturacion_global
            FROM metricas_cliente mc
            CROSS JOIN total_plataforma tp
            ORDER BY mc.gasto_historico_total DESC
            FETCH FIRST 10 ROWS ONLY
        """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new AnaliticaClienteClvDto(
                rs.getLong("ID_CLIENTE"),
                rs.getString("NOMBRE_COMPLETO"),
                rs.getLong("TOTAL_ESTADIAS"),
                rs.getLong("TOTAL_SERVICIOS_CONTRATADOS"),
                rs.getBigDecimal("GASTO_HISTORICO_TOTAL"),
                rs.getBigDecimal("TICKET_PROMEDIO"),
                rs.getBigDecimal("PCT_FACTURACION_GLOBAL")
        ));
    }
}
