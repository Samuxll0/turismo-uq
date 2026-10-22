package com.turismouq.app.dto.response;

import java.util.List;

/**
 * Resumen consolidado del Tablespace dedicado TBS_HISTORICO_RESERVAS con sus métricas DBA.
 */
public record TablespaceInfoDto(
        String tablespaceName,
        String status,
        String extentManagement,
        String allocationType,
        String segmentSpaceManagement,
        Integer blockSizeBytes,
        Double initialSizeMb,
        Double autoextendNextMb,
        Double maxSizeMb,
        Long usedBytes,
        Double usedMb,
        Double pctUsedOfInitial,
        Double pctUsedOfMax,
        String quotaUser,
        String datafileName,
        String datafilePath,
        Long totalFilasHistoricas,
        List<TablespaceTablaDto> tablas,
        List<TablespaceIndexDto> indices
) {}
