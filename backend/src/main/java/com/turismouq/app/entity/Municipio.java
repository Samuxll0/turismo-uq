package com.turismouq.app.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "MUNICIPIO", schema = "TURISMO_UQ")
public class Municipio {

    @Id
    @Column(name = "ID_MUNICIPIO")
    private Long idMunicipio;

    @Column(name = "NOMBRE", nullable = false, length = 60)
    private String nombre;
}
