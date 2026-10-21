package com.turismouq.app.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;

public record ReservaResponseDto(
    Long idReserva,
    Long idCliente,
    String nombreCliente,
    Long idHabitacion,
    String nombreHabitacion,
    String nombreAlojamiento,
    LocalDate fechaIn,
    LocalDate fechaOut,
    BigDecimal total,
    String estado
) {}
