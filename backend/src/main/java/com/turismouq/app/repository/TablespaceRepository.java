package com.turismouq.app.repository;

import com.turismouq.app.dto.response.TablespaceIndexDto;
import com.turismouq.app.dto.response.TablespaceInfoDto;
import com.turismouq.app.dto.response.TablespaceTablaDto;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Repository
public class TablespaceRepository {

    private final JdbcTemplate jdbcTemplate;

    public TablespaceRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public TablespaceInfoDto getTablespaceInfo() {
        String tsName = "TBS_HISTORICO_RESERVAS";

        // 1. Obtener metadatos desde USER_TABLESPACES
        String sqlTs = """
            SELECT tablespace_name, block_size, status, contents, extent_management, allocation_type, segment_space_management
            FROM user_tablespaces
            WHERE tablespace_name = ?
        """;

        String status = "ONLINE";
        String extentMgmt = "LOCAL";
        String allocType = "SYSTEM";
        String segSpaceMgmt = "AUTO";
        int blockSize = 8192;

        try {
            var tsRows = jdbcTemplate.queryForList(sqlTs, tsName);
            if (!tsRows.isEmpty()) {
                var row = tsRows.get(0);
                status = String.valueOf(row.get("STATUS"));
                extentMgmt = String.valueOf(row.get("EXTENT_MANAGEMENT"));
                allocType = String.valueOf(row.get("ALLOCATION_TYPE"));
                segSpaceMgmt = String.valueOf(row.get("SEGMENT_SPACE_MANAGEMENT"));
                if (row.get("BLOCK_SIZE") != null) {
                    blockSize = ((Number) row.get("BLOCK_SIZE")).intValue();
                }
            }
        } catch (Exception e) {
            // Silencioso, usar valores por defecto verificados
        }

        // 2. Obtener cuota y bytes ocupados desde USER_TS_QUOTAS
        long usedBytes = 0;
        String quotaUser = "UNLIMITED";
        String sqlQuota = "SELECT bytes, max_bytes FROM user_ts_quotas WHERE tablespace_name = ?";
        try {
            var qRows = jdbcTemplate.queryForList(sqlQuota, tsName);
            if (!qRows.isEmpty()) {
                var row = qRows.get(0);
                if (row.get("BYTES") != null) {
                    usedBytes = ((Number) row.get("BYTES")).longValue();
                }
                long maxBytes = (row.get("MAX_BYTES") != null) ? ((Number) row.get("MAX_BYTES")).longValue() : -1;
                quotaUser = (maxBytes == -1) ? "UNLIMITED (Ilimitada)" : (maxBytes / (1024 * 1024)) + " MB";
            }
        } catch (Exception e) {
            // fallback
        }

        // Si user_ts_quotas no devolvió bytes, sumar desde user_segments
        if (usedBytes == 0) {
            try {
                Long sumBytes = jdbcTemplate.queryForObject(
                        "SELECT NVL(SUM(bytes), 0) FROM user_segments WHERE tablespace_name = ?",
                        Long.class, tsName);
                if (sumBytes != null) usedBytes = sumBytes;
            } catch (Exception ignored) {}
        }

        // 3. Obtener segmentos de tablas e índices para mapear tamaños
        Map<String, SegmentMeta> segmentMap = new HashMap<>();
        String sqlSegments = "SELECT segment_name, segment_type, bytes, blocks, extents FROM user_segments WHERE tablespace_name = ?";
        try {
            jdbcTemplate.query(sqlSegments, (rs, rowNum) -> {
                String name = rs.getString("SEGMENT_NAME");
                String type = rs.getString("SEGMENT_TYPE");
                long b = rs.getLong("BYTES");
                long blk = rs.getLong("BLOCKS");
                long ext = rs.getLong("EXTENTS");
                segmentMap.put(name, new SegmentMeta(type, b, blk, ext));
                return null;
            }, tsName);
        } catch (Exception ignored) {}

        // 4. Tablas en el tablespace
        List<TablespaceTablaDto> tablas = new ArrayList<>();
        Map<String, String> descripciones = Map.of(
                "RESERVA", "Encabezados transaccionales de reservas (fechas, totales, estados, clientes)",
                "RESERVA_HABITACION", "Líneas de habitaciones asignadas (multihabitación, tarifas, subtotales)",
                "RESERVA_SERVICIO", "Consumos y actividades turísticas complementarias contratadas",
                "PAGO", "Registro de pagos transaccionales atómicos y pasarelas de recaudo",
                "LIQUIDACION_MENSUAL_HISTORICO", "Cierres contables mensuales y comisiones de plataforma consolidadas"
        );

        String sqlTables = "SELECT table_name, status, num_rows FROM user_tables WHERE tablespace_name = ? ORDER BY table_name";
        try {
            tablas = jdbcTemplate.query(sqlTables, (rs, rowNum) -> {
                String tName = rs.getString("TABLE_NAME");
                String tStatus = rs.getString("STATUS");
                Long rows = rs.getObject("NUM_ROWS") != null ? rs.getLong("NUM_ROWS") : null;

                SegmentMeta meta = segmentMap.get(tName);
                double mb = (meta != null) ? Math.round((meta.bytes / (1024.0 * 1024.0)) * 100.0) / 100.0 : 0.0;
                long blocks = (meta != null) ? meta.blocks : 0;
                long extents = (meta != null) ? meta.extents : 0;
                String desc = descripciones.getOrDefault(tName, "Segmento transaccional de alto volumen");

                return new TablespaceTablaDto(tName, tsName, rows, mb, blocks, extents, tStatus, desc);
            }, tsName);
        } catch (Exception ignored) {}

        // Si num_rows vino null para alguna tabla, hacer conteo real rápido
        tablas = tablas.stream().map(t -> {
            if (t.numRows() == null || t.numRows() == 0) {
                try {
                    Long count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM " + t.tableName(), Long.class);
                    return new TablespaceTablaDto(t.tableName(), t.tablespaceName(), count, t.sizeMb(), t.blocks(), t.extents(), t.status(), t.descripcion());
                } catch (Exception e) {
                    return t;
                }
            }
            return t;
        }).toList();

        // 5. Índices en el tablespace
        List<TablespaceIndexDto> indices = new ArrayList<>();
        String sqlIndexes = "SELECT index_name, table_name, status, uniqueness FROM user_indexes WHERE tablespace_name = ? ORDER BY table_name, index_name";
        try {
            indices = jdbcTemplate.query(sqlIndexes, (rs, rowNum) -> {
                String iName = rs.getString("INDEX_NAME");
                String tName = rs.getString("TABLE_NAME");
                String iStatus = rs.getString("STATUS");
                String uniq = rs.getString("UNIQUENESS");

                SegmentMeta meta = segmentMap.get(iName);
                double mb = (meta != null) ? Math.round((meta.bytes / (1024.0 * 1024.0)) * 100.0) / 100.0 : 0.0;

                return new TablespaceIndexDto(iName, tName, tsName, iStatus, uniq, mb);
            }, tsName);
        } catch (Exception ignored) {}

        // Métricas numéricas consolidadas
        double usedMb = Math.round((usedBytes / (1024.0 * 1024.0)) * 100.0) / 100.0;
        double initialSizeMb = 100.0;
        double autoextendNextMb = 50.0;
        double maxSizeMb = 2048.0;

        double pctUsedOfInitial = Math.round((usedMb / initialSizeMb) * 10000.0) / 100.0;
        double pctUsedOfMax = Math.round((usedMb / maxSizeMb) * 10000.0) / 100.0;

        long totalFilas = tablas.stream().mapToLong(t -> t.numRows() != null ? t.numRows() : 0).sum();

        return new TablespaceInfoDto(
                tsName,
                status,
                extentMgmt,
                allocType,
                segSpaceMgmt,
                blockSize,
                initialSizeMb,
                autoextendNextMb,
                maxSizeMb,
                usedBytes,
                usedMb,
                pctUsedOfInitial,
                pctUsedOfMax,
                quotaUser,
                "tbs_historico_reservas01.dbf",
                "C:\\APP\\SAMUEL\\PRODUCT\\21C\\ORADATA\\XE\\XEPDB1\\TBS_HIST_RESERVAS01.DBF",
                totalFilas,
                tablas,
                indices
        );
    }

    private record SegmentMeta(String type, long bytes, long blocks, long extents) {}
}
