package com.turismouq.app.service;

import com.turismouq.app.dto.response.CatalogoItemDto;
import com.turismouq.app.dto.response.HabitacionDetalleDto;
import com.turismouq.app.entity.Habitacion;
import com.turismouq.app.entity.Tarifa;
import com.turismouq.app.repository.*;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class CatalogoService {

    private final MunicipioRepository municipioRepository;
    private final AlojamientoRepository alojamientoRepository;
    private final HabitacionRepository habitacionRepository;
    private final ClienteRepository clienteRepository;
    private final TarifaRepository tarifaRepository;

    public CatalogoService(MunicipioRepository municipioRepository,
                           AlojamientoRepository alojamientoRepository,
                           HabitacionRepository habitacionRepository,
                           ClienteRepository clienteRepository,
                           TarifaRepository tarifaRepository) {
        this.municipioRepository = municipioRepository;
        this.alojamientoRepository = alojamientoRepository;
        this.habitacionRepository = habitacionRepository;
        this.clienteRepository = clienteRepository;
        this.tarifaRepository = tarifaRepository;
    }

    public List<CatalogoItemDto> listarMunicipios() {
        return municipioRepository.findAllByOrderByNombreAsc().stream()
                .map(m -> new CatalogoItemDto(m.getIdMunicipio(), m.getNombre(), "Municipio del Quindío"))
                .toList();
    }

    public List<CatalogoItemDto> listarAlojamientos(Long idMunicipio) {
        var list = idMunicipio != null 
                ? alojamientoRepository.findByMunicipioIdMunicipioOrderByNombreAsc(idMunicipio)
                : alojamientoRepository.findAllByOrderByNombreAsc();
        return list.stream()
                .map(a -> new CatalogoItemDto(a.getIdAlojamiento(), a.getNombre(), a.getDireccion()))
                .toList();
    }

    public List<CatalogoItemDto> listarClientes() {
        return clienteRepository.findTop50ByOrderByApellidosAscNombresAsc().stream()
                .map(c -> new CatalogoItemDto(c.getIdCliente(), c.getNombreCompleto(), c.getDocumento() + " - " + c.getCorreo()))
                .toList();
    }

    public List<HabitacionDetalleDto> listarHabitaciones(Long idAlojamiento) {
        List<Habitacion> habitaciones = idAlojamiento != null
                ? habitacionRepository.findByAlojamientoIdAlojamientoOrderByNumeroNombreAsc(idAlojamiento)
                : habitacionRepository.findAllWithDetails();

        List<Tarifa> todasTarifas = tarifaRepository.findAll();
        Map<Long, Map<Long, BigDecimal>> tarifasPorHabitacion = todasTarifas.stream()
                .collect(Collectors.groupingBy(
                        t -> t.getHabitacion().getIdHabitacion(),
                        Collectors.toMap(Tarifa::getIdTemporada, Tarifa::getPrecioNoche, (v1, v2) -> v1)
                ));

        return habitaciones.stream().map(h -> {
            var map = tarifasPorHabitacion.getOrDefault(h.getIdHabitacion(), Map.of());
            BigDecimal baja = map.getOrDefault(1L, BigDecimal.ZERO);
            BigDecimal alta = map.getOrDefault(2L, BigDecimal.ZERO);
            return new HabitacionDetalleDto(
                    h.getIdHabitacion(),
                    h.getNumeroNombre(),
                    h.getCapacidad(),
                    h.getTipoCama(),
                    h.getAlojamiento().getIdAlojamiento(),
                    h.getAlojamiento().getNombre(),
                    h.getAlojamiento().getMunicipio().getNombre(),
                    baja,
                    alta
            );
        }).toList();
    }
}
