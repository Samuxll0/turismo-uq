package com.turismouq.app.dto.response;

import java.math.BigDecimal;

/**
 * Consulta 5: Consulta parametrizada con variables de enlace (Bind Variables).
 */
public record AnaliticaRangoFechasDto(
        String municipio,
        Long reservasPeriodo,
        BigDecimal totalRecaudado,
        BigDecimal ticketPromedio
) {}
