package com.turismouq.app.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
@Entity
@Table(name = "TARIFA", schema = "TURISMO_UQ")
public class Tarifa {

    @Id
    @Column(name = "ID_TARIFA")
    private Long idTarifa;

    @Column(name = "PRECIO_NOCHE", nullable = false, precision = 12, scale = 2)
    private BigDecimal precioNoche;

    @Column(name = "ID_TEMPORADA", nullable = false)
    private Long idTemporada;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ID_HABITACION", nullable = false)
    private Habitacion habitacion;
}
