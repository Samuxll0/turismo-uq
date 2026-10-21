package com.turismouq.app.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "ALOJAMIENTO", schema = "TURISMO_UQ")
public class Alojamiento {

    @Id
    @Column(name = "ID_ALOJAMIENTO")
    private Long idAlojamiento;

    @Column(name = "NOMBRE", nullable = false, length = 100)
    private String nombre;

    @Column(name = "DIRECCION", length = 150)
    private String direccion;

    @Column(name = "TELEFONO", length = 30)
    private String telefono;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ID_MUNICIPIO", nullable = false)
    private Municipio municipio;
}
