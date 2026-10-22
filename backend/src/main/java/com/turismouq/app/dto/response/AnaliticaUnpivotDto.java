package com.turismouq.app.dto.response;

import java.math.BigDecimal;

/**
 * Consulta 7: Despivotado de métricas paralelas (UNPIVOT).
 */
public record AnaliticaUnpivotDto(
        Long idReserva,
        String mes,
        String conceptoGasto,
        BigDecimal monto
) {}
