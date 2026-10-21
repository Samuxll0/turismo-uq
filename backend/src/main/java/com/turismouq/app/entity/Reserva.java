package com.turismouq.app.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Getter
@Setter
@Entity
@Table(name = "RESERVA", schema = "TURISMO_UQ")
public class Reserva {

    @Id
    @Column(name = "ID_RESERVA")
    private Long idReserva;

    @Column(name = "FECHA_CREACION", nullable = false)
    private LocalDate fechaCreacion;

    @Column(name = "FECHA_CHECK_IN", nullable = false)
    private LocalDate fechaCheckIn;

    @Column(name = "FECHA_CHECK_OUT", nullable = false)
    private LocalDate fechaCheckOut;

    @Column(name = "TOTAL", nullable = false, precision = 14, scale = 2)
    private BigDecimal total;

    @Column(name = "ESTADO", nullable = false, length = 25)
    private String estado;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ID_CLIENTE", nullable = false)
    private Cliente cliente;
}
