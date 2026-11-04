package com.turismouq.app.controller;

import com.turismouq.app.dto.request.ReservaTransaccionalRequestDto;
import com.turismouq.app.dto.request.SimularConcurrenciaRequestDto;
import com.turismouq.app.dto.response.ReservaTransaccionalResponseDto;
import com.turismouq.app.dto.response.SimulacionConcurrenciaResponseDto;
import com.turismouq.app.service.TransaccionService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/transacciones")
public class TransaccionController {

    private final TransaccionService transaccionService;

    public TransaccionController(TransaccionService transaccionService) {
        this.transaccionService = transaccionService;
    }

    @PostMapping("/reserva-con-pago")
    public ResponseEntity<ReservaTransaccionalResponseDto> registrarReservaConPago(
            @RequestBody ReservaTransaccionalRequestDto dto) {
        return ResponseEntity.ok(transaccionService.registrarReservaConPago(dto));
    }

    @PostMapping("/simular-concurrencia")
    public ResponseEntity<SimulacionConcurrenciaResponseDto> simularConcurrencia(
            @RequestBody(required = false) SimularConcurrenciaRequestDto dto) {
        return ResponseEntity.ok(transaccionService.simularConcurrenciaDosSesiones(dto));
    }
}
