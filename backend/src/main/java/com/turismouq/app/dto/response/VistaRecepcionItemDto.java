package com.turismouq.app.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;

public record VistaRecepcionItemDto(
    Long idReserva,
    LocalDate fechaCheckIn,
    LocalDate fechaCheckOut,
    Integer nochesEstadia,
    String estadoReserva,
    BigDecimal valorTotal,
    String documentoCliente,
    String nombreHuesped,
    String habitacion,
    String alojamiento,
    String municipio,
    String estadoPago,
    String medioPago
) {}
