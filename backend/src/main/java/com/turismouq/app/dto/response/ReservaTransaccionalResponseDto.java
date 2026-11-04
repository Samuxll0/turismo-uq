package com.turismouq.app.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;

public record ReservaTransaccionalResponseDto(
    Long idReserva,
    Long idPago,
    Long idCliente,
    String nombreCliente,
    Long idHabitacion,
    String nombreHabitacion,
    String nombreAlojamiento,
    LocalDate fechaIn,
    LocalDate fechaOut,
    BigDecimal totalReserva,
    BigDecimal montoPago,
    String metodoPago,
    String estadoReserva,
    String estadoPago,
    boolean rollbackParcial,
    String savepointUtilizado,
    String mensaje,
    long duracionMs
) {}
