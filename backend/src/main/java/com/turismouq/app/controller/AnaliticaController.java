package com.turismouq.app.controller;

import com.turismouq.app.dto.response.AnaliticaJerarquiaDto;
import com.turismouq.app.dto.response.AnaliticaOcupacionDto;
import com.turismouq.app.dto.response.AnaliticaTopAlojamientoDto;
import com.turismouq.app.dto.response.AnaliticaVariacionDto;
import com.turismouq.app.service.AnaliticaService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/analitica")
public class AnaliticaController {

    private final AnaliticaService analiticaService;

    public AnaliticaController(AnaliticaService analiticaService) {
        this.analiticaService = analiticaService;
    }

    @GetMapping("/ocupacion-mensual")
    public ResponseEntity<List<AnaliticaOcupacionDto>> getOcupacionMensual() {
        return ResponseEntity.ok(analiticaService.obtenerOcupacionMensualPivot());
    }

    @GetMapping("/ingresos-jerarquia")
    public ResponseEntity<List<AnaliticaJerarquiaDto>> getIngresosJerarquia() {
        return ResponseEntity.ok(analiticaService.obtenerIngresosJerarquiaRollup());
    }

    @GetMapping("/top-alojamientos")
    public ResponseEntity<List<AnaliticaTopAlojamientoDto>> getTopAlojamientos() {
        return ResponseEntity.ok(analiticaService.obtenerTopAlojamientos());
    }

    @GetMapping("/variacion-mes")
    public ResponseEntity<List<AnaliticaVariacionDto>> getVariacionMes() {
        return ResponseEntity.ok(analiticaService.obtenerVariacionMesLag());
    }
}
