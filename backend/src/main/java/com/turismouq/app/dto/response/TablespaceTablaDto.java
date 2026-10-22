package com.turismouq.app.dto.response;

/**
 * Representa una tabla física alojada en el Tablespace TBS_HISTORICO_RESERVAS.
 */
public record TablespaceTablaDto(
        String tableName,
        String tablespaceName,
        Long numRows,
        Double sizeMb,
        Long blocks,
        Long extents,
        String status,
        String descripcion
) {}
