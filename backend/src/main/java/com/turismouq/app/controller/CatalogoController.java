package com.turismouq.app.controller;

import com.turismouq.app.dto.response.CatalogoItemDto;
import com.turismouq.app.dto.response.HabitacionDetalleDto;
import com.turismouq.app.service.CatalogoService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/catalogos")
public class CatalogoController {

    private final CatalogoService catalogoService;

    public CatalogoController(CatalogoService catalogoService) {
        this.catalogoService = catalogoService;
    }

    @GetMapping("/municipios")
    public ResponseEntity<List<CatalogoItemDto>> getMunicipios() {
        return ResponseEntity.ok(catalogoService.listarMunicipios());
    }

    @GetMapping("/alojamientos")
    public ResponseEntity<List<CatalogoItemDto>> getAlojamientos(@RequestParam(required = false) Long idMunicipio) {
        return ResponseEntity.ok(catalogoService.listarAlojamientos(idMunicipio));
    }

    @GetMapping("/habitaciones")
    public ResponseEntity<List<HabitacionDetalleDto>> getHabitaciones(@RequestParam(required = false) Long idAlojamiento) {
        return ResponseEntity.ok(catalogoService.listarHabitaciones(idAlojamiento));
    }

    @GetMapping("/clientes")
    public ResponseEntity<List<CatalogoItemDto>> getClientes() {
        return ResponseEntity.ok(catalogoService.listarClientes());
    }
}
