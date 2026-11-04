package com.turismouq.app.controller;

import com.turismouq.app.dto.response.PerfilLimiteDto;
import com.turismouq.app.dto.response.RolSeguridadDto;
import com.turismouq.app.dto.response.VistaRecepcionItemDto;
import com.turismouq.app.service.SeguridadService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/seguridad")
public class SeguridadController {

    private final SeguridadService seguridadService;

    public SeguridadController(SeguridadService seguridadService) {
        this.seguridadService = seguridadService;
    }

    @GetMapping("/roles")
    public ResponseEntity<List<RolSeguridadDto>> obtenerRoles() {
        return ResponseEntity.ok(seguridadService.obtenerRolesMatriz());
    }

    @GetMapping("/perfiles")
    public ResponseEntity<List<PerfilLimiteDto>> obtenerPerfiles() {
        return ResponseEntity.ok(seguridadService.obtenerPerfilLimites());
    }

    @GetMapping("/vista-recepcion")
    public ResponseEntity<List<VistaRecepcionItemDto>> consultarVistaRecepcion(
            @RequestParam(name = "limite", defaultValue = "12") int limite) {
        return ResponseEntity.ok(seguridadService.consultarVistaRecepcion(limite));
    }
}
