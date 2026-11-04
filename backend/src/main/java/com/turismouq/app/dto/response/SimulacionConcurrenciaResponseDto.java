package com.turismouq.app.dto.response;

import java.time.LocalDate;
import java.util.List;

public record SimulacionConcurrenciaResponseDto(
    Long idHabitacion,
    String nombreHabitacion,
    String nombreAlojamiento,
    LocalDate fechaIn,
    LocalDate fechaOut,
    String sentenciaBloqueo,
    String sesion1Estado,
    Long sesion1ReservaId,
    String sesion1Detalle,
    String sesion2Estado,
    String sesion2CodigoError,
    String sesion2Detalle,
    long tiempoEsperaSesion2Ms,
    List<String> eventosTimeline,
    String comportamientoAntes,
    String comportamientoDespues
) {}
