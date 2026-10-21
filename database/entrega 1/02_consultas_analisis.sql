-- ========================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- ENTREGA 1: OCHO CONSULTAS DE ANALISIS OBLIGATORIAS
-- ========================================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = TURISMO_UQ;

-- ========================================================================
-- Consulta 1: Ocupacion por Municipio y Mes (Utilizando PIVOT)
-- Proposito: Generar una matriz bidimensional (tipo tabla dinamica) para
--            visualizar la distribucion estacional de la demanda en 2025.
-- ========================================================================
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
ORDER BY municipio;

-- ========================================================================
-- Consulta 2: Ingresos por Municipio, Tipo y Temporada (ROLLUP + GROUPING)
-- Proposito: Producir un reporte financiero jerarquico multinivel con subtotales
--            automaticos y gran total consolidado.
-- ========================================================================
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
WHERE r.fecha_check_in BETWEEN t.fecha_inicio AND t.fecha_fin
GROUP BY ROLLUP(m.nombre, ta.nombre, t.nombre)
ORDER BY GROUPING(m.nombre), m.nombre, GROUPING(ta.nombre), ta.nombre;

-- ========================================================================
-- Consulta 3: Top 3 Alojamientos de Mayor Ingreso (DENSE_RANK + PARTITION BY)
-- Proposito: Identificar el podio de hospedajes lideres en captacion economica
--            dentro de cada uno de los 12 municipios.
-- ========================================================================
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
ORDER BY municipio, posicion_ranking;

-- ========================================================================
-- Consulta 4: Variacion de Ingresos Mes contra Mes (Utilizando LAG)
-- Proposito: Evaluar la evolucion temporal del flujo financiero y medir el
--            crecimiento o contraccion intermensual.
-- ========================================================================
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
ORDER BY periodo_mes;

-- ========================================================================
-- Consulta 5: Consulta Parametrizada con Variables de Enlace (Bind Variables)
-- Proposito: Optimizar el rendimiento del SGA reutilizando planes en el
--            Library Cache (evitar Hard Parse) y proteger contra SQL Injection.
-- ========================================================================
VARIABLE b_fecha_inicio VARCHAR2(10);
VARIABLE b_fecha_fin   VARCHAR2(10);

EXEC :b_fecha_inicio := '2025-06-01';
EXEC :b_fecha_fin    := '2025-08-31';

SELECT 
    m.nombre AS municipio,
    COUNT(r.id_reserva) AS reservas_periodo,
    SUM(r.total) AS total_recaudado,
    ROUND(AVG(r.total), 2) AS ticket_promedio
FROM MUNICIPIO m
JOIN ALOJAMIENTO a         ON m.id_municipio = a.id_municipio
JOIN HABITACION h          ON a.id_alojamiento = h.id_alojamiento
JOIN RESERVA_HABITACION rh ON h.id_habitacion = rh.id_habitacion
JOIN RESERVA r             ON rh.id_reserva = r.id_reserva
WHERE r.fecha_check_in >= TO_DATE(:b_fecha_inicio, 'YYYY-MM-DD')
  AND r.fecha_check_in <= TO_DATE(:b_fecha_fin, 'YYYY-MM-DD')
GROUP BY m.nombre
ORDER BY total_recaudado DESC;

-- ========================================================================
-- Consulta 6: Vista Materializada de Ocupacion Mensual
-- Proposito: Persistir fisicamente en disco agregados pesados para responder
--            en tiempo record a tableros directivos.
-- ========================================================================
-- Nota: La creacion de la MV se ejecuta una vez en el esquema:
/*
CREATE MATERIALIZED VIEW MV_OCUPACION_MENSUAL
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT 
    m.id_municipio,
    m.nombre AS municipio,
    ta.nombre AS tipo_alojamiento,
    TO_CHAR(r.fecha_check_in, 'YYYY-MM') AS anio_mes,
    COUNT(DISTINCT r.id_reserva) AS total_reservas,
    COUNT(rh.id_habitacion) AS total_habitaciones_ocupadas,
    SUM(r.total) AS facturacion_acumulada
FROM MUNICIPIO m
JOIN ALOJAMIENTO a         ON m.id_municipio = a.id_municipio
JOIN TIPO_ALOJAMIENTO ta   ON a.id_tipo_alojamiento = ta.id_tipo_alojamiento
JOIN HABITACION h          ON a.id_alojamiento = h.id_alojamiento
JOIN RESERVA_HABITACION rh ON h.id_habitacion = rh.id_habitacion
JOIN RESERVA r             ON rh.id_reserva = r.id_reserva
GROUP BY 
    m.id_municipio, 
    m.nombre, 
    ta.nombre, 
    TO_CHAR(r.fecha_check_in, 'YYYY-MM');
*/

SELECT * 
FROM MV_OCUPACION_MENSUAL 
WHERE anio_mes = '2025-07' 
ORDER BY facturacion_acumulada DESC;

-- ========================================================================
-- Consulta 7: Despivotado de Metricas (UNPIVOT)
-- Proposito: Normalizar verticalmente registros que agrupan componentes
--            financieros en columnas paralelas.
-- ========================================================================
WITH resumen_componentes AS (
    SELECT 
        r.id_reserva,
        TO_CHAR(r.fecha_check_in, 'YYYY-MM') AS mes,
        SUM(rh.subtotal) AS ingreso_hospedaje,
        NVL(SUM(rs.subtotal), 0) AS ingreso_servicios
    FROM RESERVA r
    JOIN RESERVA_HABITACION rh ON r.id_reserva = rh.id_reserva
    LEFT JOIN RESERVA_SERVICIO rs ON r.id_reserva = rs.id_reserva
    WHERE r.fecha_check_in BETWEEN DATE '2025-01-01' AND DATE '2025-01-31'
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
WHERE ROWNUM <= 25;

-- ========================================================================
-- Consulta 8: Clientes con Mayor Valor de Vida Transaccional (CLV)
-- Proposito: Identificar el Top 10 de clientes mas valiosos, su cuota de
--            facturacion global y adopcion de servicios complementarios.
-- ========================================================================
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
FETCH FIRST 10 ROWS ONLY;
