package com.turismouq.app.dto.response;

import java.math.BigDecimal;

public record AnaliticaVariacionDto(
    String anioMes,
    BigDecimal facturacionActual,
    BigDecimal facturacionMesAnterior,
    BigDecimal diferenciaNeta,
    BigDecimal porcentajeCrecimiento
) {}
