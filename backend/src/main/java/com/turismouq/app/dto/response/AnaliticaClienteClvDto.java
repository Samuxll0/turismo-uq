package com.turismouq.app.dto.response;

import java.math.BigDecimal;

/**
 * Consulta 8: Top 10 Clientes con Mayor Valor de Vida Transaccional (CLV) con FETCH FIRST 10 ROWS ONLY.
 */
public record AnaliticaClienteClvDto(
        Long idCliente,
        String nombreCompleto,
        Long totalEstadias,
        Long totalServiciosContratados,
        BigDecimal gastoHistoricoTotal,
        BigDecimal ticketPromedio,
        BigDecimal pctFacturacionGlobal
) {}
