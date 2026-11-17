package com.turismouq.app.dto.response;

import java.math.BigDecimal;

/**
 * Consulta 10: Listado de clientes que han reservado en más municipios distintos del Quindío.
 */
public record AnaliticaClienteMunicipiosDto(
        Long idCliente,
        String cliente,
        String documento,
        Long totalMunicipios,
        Long totalReservas,
        BigDecimal gastoTotal,
        String municipiosVisitados
) {}
