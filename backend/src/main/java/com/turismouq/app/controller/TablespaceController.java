package com.turismouq.app.controller;

import com.turismouq.app.dto.response.TablespaceInfoDto;
import com.turismouq.app.service.TablespaceService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/tablespace")
public class TablespaceController {

    private final TablespaceService tablespaceService;

    public TablespaceController(TablespaceService tablespaceService) {
        this.tablespaceService = tablespaceService;
    }

    @GetMapping("/info")
    public ResponseEntity<TablespaceInfoDto> getInfo() {
        return ResponseEntity.ok(tablespaceService.obtenerDetalleTablespace());
    }
}
