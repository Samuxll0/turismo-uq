package com.turismouq.app.dto.response;

import java.math.BigDecimal;

public record HabitacionDetalleDto(
    Long idHabitacion,
    String numeroNombre,
    Integer capacidad,
    String tipoCama,
    Long idAlojamiento,
    String nombreAlojamiento,
    String nombreMunicipio,
    BigDecimal tarifaBaja,
    BigDecimal tarifaAlta
) {}
