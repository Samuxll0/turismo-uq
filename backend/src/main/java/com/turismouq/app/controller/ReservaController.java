package com.turismouq.app.controller;

import com.turismouq.app.dto.request.CotizarRequestDto;
import com.turismouq.app.dto.request.CrearReservaRequestDto;
import com.turismouq.app.dto.response.CotizacionResponseDto;
import com.turismouq.app.dto.response.ReservaResponseDto;
import com.turismouq.app.service.PlsqlEngineService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/reservas")
public class ReservaController {

    private final PlsqlEngineService plsqlEngineService;

    public ReservaController(PlsqlEngineService plsqlEngineService) {
        this.plsqlEngineService = plsqlEngineService;
    }

    @PostMapping("/cotizar")
    public ResponseEntity<CotizacionResponseDto> cotizar(@Valid @RequestBody CotizarRequestDto request) {
        CotizacionResponseDto response = plsqlEngineService.cotizarEstadia(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping
    public ResponseEntity<ReservaResponseDto> crearReserva(@Valid @RequestBody CrearReservaRequestDto request) {
        ReservaResponseDto response = plsqlEngineService.crearReserva(request);
        return new ResponseEntity<>(response, HttpStatus.CREATED);
    }
}
