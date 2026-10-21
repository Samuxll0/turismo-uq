package com.turismouq.app.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;

public record CotizacionResponseDto(
    Long idHabitacion,
    String nombreHabitacion,
    String nombreAlojamiento,
    LocalDate fechaIn,
    LocalDate fechaOut,
    long totalNoches,
    BigDecimal tarifaBaja,
    BigDecimal tarifaAlta,
    BigDecimal totalCalculado
) {}
