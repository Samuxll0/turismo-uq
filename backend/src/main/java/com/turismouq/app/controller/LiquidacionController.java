package com.turismouq.app.controller;

import com.turismouq.app.dto.response.LiquidacionItemDto;
import com.turismouq.app.service.PlsqlEngineService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/liquidaciones")
public class LiquidacionController {

    private final PlsqlEngineService plsqlEngineService;

    public LiquidacionController(PlsqlEngineService plsqlEngineService) {
        this.plsqlEngineService = plsqlEngineService;
    }

    @GetMapping
    public ResponseEntity<List<LiquidacionItemDto>> liquidar(
            @RequestParam(defaultValue = "7") int mes,
            @RequestParam(defaultValue = "2025") int anio,
            @RequestParam(required = false) Long idAlojamiento,
            @RequestParam(defaultValue = "false") boolean procesar) {

        List<LiquidacionItemDto> resultado;
        if (procesar) {
            resultado = plsqlEngineService.ejecutarLiquidacionMensual(mes, anio, idAlojamiento);
        } else {
            resultado = plsqlEngineService.consultarLiquidacionesHistorico(mes, anio, idAlojamiento);
        }
        return ResponseEntity.ok(resultado);
    }

    @RequestMapping(value = "/procesar", method = {RequestMethod.POST, RequestMethod.GET})
    public ResponseEntity<List<LiquidacionItemDto>> procesar(
            @RequestParam(defaultValue = "7") int mes,
            @RequestParam(defaultValue = "2025") int anio,
            @RequestParam(required = false) Long idAlojamiento) {

        List<LiquidacionItemDto> resultado = plsqlEngineService.ejecutarLiquidacionMensual(mes, anio, idAlojamiento);
        return ResponseEntity.ok(resultado);
    }

    @PostMapping
    public ResponseEntity<List<LiquidacionItemDto>> procesarPost(
            @RequestParam(defaultValue = "7") int mes,
            @RequestParam(defaultValue = "2025") int anio,
            @RequestParam(required = false) Long idAlojamiento) {

        List<LiquidacionItemDto> resultado = plsqlEngineService.ejecutarLiquidacionMensual(mes, anio, idAlojamiento);
        return ResponseEntity.ok(resultado);
    }

    @RequestMapping(value = "/limpiar", method = {RequestMethod.DELETE, RequestMethod.POST, RequestMethod.GET})
    public ResponseEntity<Void> limpiarHistorico() {
        plsqlEngineService.limpiarLiquidacionesHistorico();
        return ResponseEntity.noContent().build();
    }
}
