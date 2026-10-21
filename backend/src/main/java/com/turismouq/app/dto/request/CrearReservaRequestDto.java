package com.turismouq.app.dto.request;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;

public record CrearReservaRequestDto(
    @NotNull(message = "El id del cliente es obligatorio")
    Long idCliente,

    @NotNull(message = "El id de la habitación es obligatorio")
    Long idHabitacion,

    @NotNull(message = "La fecha de check-in es obligatoria")
    LocalDate fechaIn,

    @NotNull(message = "La fecha de check-out es obligatoria")
    LocalDate fechaOut,

    @NotNull(message = "El número de huéspedes es obligatorio")
    @Min(value = 1, message = "Debe haber al menos 1 huésped")
    Integer numHuespedes
) {}
