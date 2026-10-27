package com.turismouq.app.dto.response;

public record PeriodoTemporadaDto(
        Long idPeriodo,
        Long idTemporada,
        String nombre,
        String fechaInicio,
        String fechaFin,
        Long diasDuracion
) {}
