package com.turismouq.app.dto.response;

import java.math.BigDecimal;

/**
 * Consulta 6: Vista Materializada de ocupación mensual (MV_OCUPACION_MENSUAL).
 */
public record AnaliticaMaterializadaDto(
        Long idMunicipio,
        String municipio,
        String tipoAlojamiento,
        String anioMes,
        Long totalReservas,
        Long totalHabitacionesOcupadas,
        BigDecimal facturacionAcumulada
) {}
