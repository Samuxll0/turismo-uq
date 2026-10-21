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
            @RequestParam(required = false) Long idAlojamiento) {

        List<LiquidacionItemDto> resultado = plsqlEngineService.ejecutarLiquidacionMensual(mes, anio, idAlojamiento);
        return ResponseEntity.ok(resultado);
    }
}
