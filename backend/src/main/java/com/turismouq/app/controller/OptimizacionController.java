package com.turismouq.app.controller;

import com.turismouq.app.dto.response.PlanEjecucionIndiceDto;
import com.turismouq.app.service.OptimizacionService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/indices")
public class OptimizacionController {

    private final OptimizacionService optimizacionService;

    public OptimizacionController(OptimizacionService optimizacionService) {
        this.optimizacionService = optimizacionService;
    }

    @GetMapping("/planes")
    public ResponseEntity<List<PlanEjecucionIndiceDto>> obtenerPlanesEjecucion() {
        return ResponseEntity.ok(optimizacionService.obtenerPlanesEjecucion());
    }
}
