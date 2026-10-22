package com.turismouq.app.service;

import com.turismouq.app.dto.response.TablespaceInfoDto;
import com.turismouq.app.repository.TablespaceRepository;
import org.springframework.stereotype.Service;

@Service
public class TablespaceService {

    private final TablespaceRepository tablespaceRepository;

    public TablespaceService(TablespaceRepository tablespaceRepository) {
        this.tablespaceRepository = tablespaceRepository;
    }

    public TablespaceInfoDto obtenerDetalleTablespace() {
        return tablespaceRepository.getTablespaceInfo();
    }
}
