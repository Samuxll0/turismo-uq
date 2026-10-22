package com.turismouq.app.service;

import com.turismouq.app.dto.response.AnaliticaJerarquiaDto;
import com.turismouq.app.dto.response.AnaliticaOcupacionDto;
import com.turismouq.app.dto.response.AnaliticaTopAlojamientoDto;
import com.turismouq.app.dto.response.AnaliticaVariacionDto;
import com.turismouq.app.dto.response.AnaliticaRangoFechasDto;
import com.turismouq.app.dto.response.AnaliticaMaterializadaDto;
import com.turismouq.app.dto.response.AnaliticaUnpivotDto;
import com.turismouq.app.dto.response.AnaliticaClienteClvDto;
import com.turismouq.app.repository.AnaliticaRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class AnaliticaService {

    private final AnaliticaRepository analiticaRepository;

    public AnaliticaService(AnaliticaRepository analiticaRepository) {
        this.analiticaRepository = analiticaRepository;
    }

    public List<AnaliticaOcupacionDto> obtenerOcupacionMensualPivot() {
        return analiticaRepository.getOcupacionMensualPivot();
    }

    public List<AnaliticaJerarquiaDto> obtenerIngresosJerarquiaRollup() {
        return analiticaRepository.getIngresosJerarquiaRollup();
    }

    public List<AnaliticaTopAlojamientoDto> obtenerTopAlojamientos() {
        return analiticaRepository.getTopAlojamientosRanking();
    }

    public List<AnaliticaVariacionDto> obtenerVariacionMesLag() {
        return analiticaRepository.getVariacionMesLag();
    }

    public List<AnaliticaRangoFechasDto> obtenerRangoFechasBind(String fechaInicio, String fechaFin) {
        return analiticaRepository.getRangoFechasBind(fechaInicio, fechaFin);
    }

    public List<AnaliticaMaterializadaDto> obtenerVistaMaterializada(String anioMes) {
        return analiticaRepository.getVistaMaterializada(anioMes);
    }

    public List<AnaliticaUnpivotDto> obtenerDespivotadoMetricas(String mes) {
        return analiticaRepository.getDespivotadoMetricas(mes);
    }

    public List<AnaliticaClienteClvDto> obtenerTopClientesClv() {
        return analiticaRepository.getTopClientesClv();
    }
}
