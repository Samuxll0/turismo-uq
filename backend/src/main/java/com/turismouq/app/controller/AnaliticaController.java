package com.turismouq.app.controller;

import com.turismouq.app.dto.response.AnaliticaJerarquiaDto;
import com.turismouq.app.dto.response.AnaliticaOcupacionDto;
import com.turismouq.app.dto.response.AnaliticaTopAlojamientoDto;
import com.turismouq.app.dto.response.AnaliticaVariacionDto;
import com.turismouq.app.dto.response.AnaliticaRangoFechasDto;
import com.turismouq.app.dto.response.AnaliticaMaterializadaDto;
import com.turismouq.app.dto.response.AnaliticaUnpivotDto;
import com.turismouq.app.dto.response.AnaliticaClienteClvDto;
import com.turismouq.app.service.AnaliticaService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
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

    @GetMapping("/rango-fechas")
    public ResponseEntity<List<AnaliticaRangoFechasDto>> getRangoFechas(
            @RequestParam(required = false, defaultValue = "2025-06-01") String fechaInicio,
            @RequestParam(required = false, defaultValue = "2025-08-31") String fechaFin) {
        return ResponseEntity.ok(analiticaService.obtenerRangoFechasBind(fechaInicio, fechaFin));
    }

    @GetMapping("/vista-materializada")
    public ResponseEntity<List<AnaliticaMaterializadaDto>> getVistaMaterializada(
            @RequestParam(required = false, defaultValue = "2025-07") String anioMes) {
        return ResponseEntity.ok(analiticaService.obtenerVistaMaterializada(anioMes));
    }

    @GetMapping("/despivotado-metricas")
    public ResponseEntity<List<AnaliticaUnpivotDto>> getDespivotadoMetricas(
            @RequestParam(required = false, defaultValue = "2025-01") String mes) {
        return ResponseEntity.ok(analiticaService.obtenerDespivotadoMetricas(mes));
    }

    @GetMapping("/top-clientes-clv")
    public ResponseEntity<List<AnaliticaClienteClvDto>> getTopClientesClv() {
        return ResponseEntity.ok(analiticaService.obtenerTopClientesClv());
    }
}
