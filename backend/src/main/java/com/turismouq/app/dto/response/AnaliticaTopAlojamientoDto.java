package com.turismouq.app.dto.response;

import java.math.BigDecimal;

public record AnaliticaTopAlojamientoDto(
    String municipio,
    Integer posicionRanking,
    String alojamiento,
    BigDecimal ingresosAlojamiento
) {}
