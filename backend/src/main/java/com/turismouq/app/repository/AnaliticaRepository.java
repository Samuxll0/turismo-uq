package com.turismouq.app.repository;

import com.turismouq.app.dto.response.AnaliticaJerarquiaDto;
import com.turismouq.app.dto.response.AnaliticaOcupacionDto;
import com.turismouq.app.dto.response.AnaliticaTopAlojamientoDto;
import com.turismouq.app.dto.response.AnaliticaVariacionDto;
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
                FROM TURISMO_UQ.RESERVA r
                JOIN TURISMO_UQ.RESERVA_HABITACION rh ON r.id_reserva = rh.id_reserva
                JOIN TURISMO_UQ.HABITACION h          ON rh.id_habitacion = h.id_habitacion
                JOIN TURISMO_UQ.ALOJAMIENTO a         ON h.id_alojamiento = a.id_alojamiento
                JOIN TURISMO_UQ.MUNICIPIO m           ON a.id_municipio = m.id_municipio
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
            FROM TURISMO_UQ.MUNICIPIO m
            JOIN TURISMO_UQ.ALOJAMIENTO a         ON m.id_municipio = a.id_municipio
            JOIN TURISMO_UQ.TIPO_ALOJAMIENTO ta   ON a.id_tipo_alojamiento = ta.id_tipo_alojamiento
            JOIN TURISMO_UQ.HABITACION h          ON a.id_alojamiento = h.id_alojamiento
            JOIN TURISMO_UQ.TARIFA tf             ON h.id_habitacion = tf.id_habitacion
            JOIN TURISMO_UQ.TEMPORADA t           ON tf.id_temporada = t.id_temporada
            JOIN TURISMO_UQ.RESERVA_HABITACION rh ON h.id_habitacion = rh.id_habitacion
            JOIN TURISMO_UQ.RESERVA r             ON rh.id_reserva = r.id_reserva
            WHERE r.fecha_check_in BETWEEN t.fecha_inicio AND t.fecha_fin
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
                FROM TURISMO_UQ.MUNICIPIO m
                JOIN TURISMO_UQ.ALOJAMIENTO a         ON m.id_municipio = a.id_municipio
                JOIN TURISMO_UQ.HABITACION h          ON a.id_alojamiento = h.id_alojamiento
                JOIN TURISMO_UQ.RESERVA_HABITACION rh ON h.id_habitacion = rh.id_habitacion
                JOIN TURISMO_UQ.RESERVA r             ON rh.id_reserva = r.id_reserva
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
                FROM TURISMO_UQ.RESERVA r
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
}
