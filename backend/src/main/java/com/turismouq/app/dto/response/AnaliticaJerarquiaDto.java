package com.turismouq.app.dto.response;

import java.math.BigDecimal;

public record AnaliticaJerarquiaDto(
    String municipio,
    String tipoAlojamiento,
    String temporada,
    Long cantidadReservas,
    BigDecimal ingresosTotales,
    int gMun,
    int gTipo,
    int gTemp
) {}
