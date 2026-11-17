package com.turismouq.app.dto.response;

import java.math.BigDecimal;

/**
 * Consulta 9: Habitación con más reservas en Temporada Alta (Top 10).
 */
public record AnaliticaHabitacionTempAltaDto(
        Integer ranking,
        Long idHabitacion,
        String habitacion,
        String alojamiento,
        String municipio,
        Integer capacidad,
        String tipoCama,
        Long reservasTemporadaAlta,
        BigDecimal ingresosHospedaje
) {}
