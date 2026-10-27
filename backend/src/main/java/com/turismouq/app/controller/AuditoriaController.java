package com.turismouq.app.controller;

import com.turismouq.app.dto.request.GuardarTarifaRequestDto;
import com.turismouq.app.dto.response.*;
import com.turismouq.app.service.AuditoriaService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/auditoria")
public class AuditoriaController {

    private final AuditoriaService auditoriaService;

    public AuditoriaController(AuditoriaService auditoriaService) {
        this.auditoriaService = auditoriaService;
    }

    @GetMapping("/tarifas")
    public ResponseEntity<List<TarifaDetalleDto>> obtenerTarifas(
            @RequestParam(required = false) Long idAlojamiento,
            @RequestParam(required = false) String busqueda) {
        return ResponseEntity.ok(auditoriaService.obtenerTarifasDetalle(idAlojamiento, busqueda));
    }

    @GetMapping("/periodos-temporada")
    public ResponseEntity<List<PeriodoTemporadaDto>> obtenerPeriodosTemporada() {
        return ResponseEntity.ok(auditoriaService.obtenerPeriodosTemporada());
    }

    @PostMapping("/guardar-tarifa")
    public ResponseEntity<Map<String, Object>> guardarTarifa(@RequestBody GuardarTarifaRequestDto request) {
        TarifaDetalleDto tarifaActualizada = auditoriaService.guardarOActualizarTarifa(request);
        Map<String, Object> resp = new java.util.LinkedHashMap<>();
        resp.put("mensaje", "Tarifas actualizadas en Oracle XE. El trigger TRG_AUDITORIA_TARIFA registró los cambios.");
        resp.put("tarifa", tarifaActualizada);
        return ResponseEntity.ok(resp);
    }

    @GetMapping("/resumen")
    public ResponseEntity<AuditoriaResumenDto> obtenerResumen() {
        return ResponseEntity.ok(auditoriaService.obtenerResumen());
    }

    @GetMapping("/filas")
    public ResponseEntity<List<AuditoriaFilaDto>> obtenerFilas(
            @RequestParam(defaultValue = "100") int limite) {
        return ResponseEntity.ok(auditoriaService.obtenerAuditoriaFilas(limite));
    }

    @GetMapping("/sentencias")
    public ResponseEntity<List<AuditoriaSentenciaDto>> obtenerSentencias(
            @RequestParam(defaultValue = "100") int limite) {
        return ResponseEntity.ok(auditoriaService.obtenerAuditoriaSentencias(limite));
    }

    @RequestMapping(value = "/simular-cambio", method = {RequestMethod.POST, RequestMethod.GET})
    public ResponseEntity<Map<String, Object>> simularCambio(
            @RequestParam(required = false) Long idHabitacion,
            @RequestParam(required = false) Long idTemporada,
            @RequestParam(defaultValue = "5.0") Double porcentaje) {

        int filasAfectadas = auditoriaService.simularAjusteTarifas(idHabitacion, idTemporada, porcentaje);
        return ResponseEntity.ok(Map.of(
                "mensaje", "Trigger TRG_AUDITORIA_TARIFA disparado exitosamente.",
                "filasAfectadas", filasAfectadas,
                "porcentajeAjuste", porcentaje
        ));
    }

    @RequestMapping(value = "/limpiar", method = {RequestMethod.DELETE, RequestMethod.POST, RequestMethod.GET})
    public ResponseEntity<Void> limpiar() {
        auditoriaService.limpiarAuditoria();
        return ResponseEntity.noContent().build();
    }
}
