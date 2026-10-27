package com.turismouq.app.dto.response;

import java.math.BigDecimal;

/**
 * Registro de auditoría a nivel de fila (AFTER EACH ROW en TRG_AUDITORIA_TARIFA).
 */
public record AuditoriaFilaDto(
        Long idAuditoria,
        String usuario,
        String fecha,
        Long idTarifa,
        Long idHabitacion,
        String numeroHabitacion,
        String nombreAlojamiento,
        String nombreTemporada,
        BigDecimal precioAnterior,
        BigDecimal precioNuevo,
        BigDecimal variacion,
        String accion
) {}
