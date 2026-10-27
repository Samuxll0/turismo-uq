package com.turismouq.app.dto.response;

/**
 * Registro de log consolidado a nivel de sentencia (AFTER STATEMENT en TRG_AUDITORIA_TARIFA).
 */
public record AuditoriaSentenciaDto(
        Long idLog,
        String usuario,
        String fecha,
        String accion,
        Long totalFilas
) {}
