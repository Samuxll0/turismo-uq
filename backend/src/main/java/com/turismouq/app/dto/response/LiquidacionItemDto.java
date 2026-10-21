package com.turismouq.app.dto.response;

import java.math.BigDecimal;

public record LiquidacionItemDto(
    Integer anio,
    Integer mes,
    Long idAlojamiento,
    String nombreAlojamiento,
    Long totalReservas,
    BigDecimal ingresoHospedaje,
    BigDecimal ingresoServicios,
    BigDecimal ingresoBruto,
    BigDecimal comisionPlataforma,
    BigDecimal netoPagar
) {}
