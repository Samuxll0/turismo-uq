package com.turismouq.app.dto.response;

import java.util.List;

/**
 * Resumen general de la actividad de auditoría y estado del Compound Trigger.
 */
public record AuditoriaResumenDto(
        Long totalFilasAuditadas,
        Long totalSentenciasDml,
        String nombreTrigger,
        String tipoTrigger,
        String estadoTrigger,
        String ultimoUsuario,
        String ultimaFecha,
        List<AuditoriaFilaDto> ultimasFilas,
        List<AuditoriaSentenciaDto> ultimasSentencias
) {}
