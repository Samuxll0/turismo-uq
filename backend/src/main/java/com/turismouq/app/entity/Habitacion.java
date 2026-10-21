package com.turismouq.app.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "HABITACION", schema = "TURISMO_UQ")
public class Habitacion {

    @Id
    @Column(name = "ID_HABITACION")
    private Long idHabitacion;

    @Column(name = "NUMERO_NOMBRE", nullable = false, length = 60)
    private String numeroNombre;

    @Column(name = "CAPACIDAD", nullable = false)
    private Integer capacidad;

    @Column(name = "TIPO_CAMA", length = 50)
    private String tipoCama;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ID_ALOJAMIENTO", nullable = false)
    private Alojamiento alojamiento;
}
