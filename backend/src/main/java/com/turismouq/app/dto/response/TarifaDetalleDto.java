package com.turismouq.app.dto.response;

import java.math.BigDecimal;

public record TarifaDetalleDto(
        Long idHabitacion,
        String numeroHabitacion,
        Integer capacidad,
        String tipoCama,
        Long idAlojamiento,
        String nombreAlojamiento,
        String nombreMunicipio,
        Long idTarifaBaja,
        BigDecimal precioBaja,
        Long idTarifaAlta,
        BigDecimal precioAlta,
        BigDecimal recargoAlta,
        Double porcentajeRecargo
) {}
