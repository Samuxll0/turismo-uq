package com.turismouq.app.dto.request;

import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;

public record CotizarRequestDto(
    @NotNull(message = "El id de la habitación es obligatorio")
    Long idHabitacion,

    @NotNull(message = "La fecha de check-in es obligatoria")
    LocalDate fechaIn,

    @NotNull(message = "La fecha de check-out es obligatoria")
    LocalDate fechaOut
) {}
