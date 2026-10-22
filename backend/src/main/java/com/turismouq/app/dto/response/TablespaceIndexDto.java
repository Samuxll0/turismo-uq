package com.turismouq.app.dto.response;

/**
 * Representa un índice reconstruido alojado en el Tablespace TBS_HISTORICO_RESERVAS.
 */
public record TablespaceIndexDto(
        String indexName,
        String tableName,
        String tablespaceName,
        String status,
        String uniqueness,
        Double sizeMb
) {}
