package com.turismouq.app.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "CLIENTE", schema = "TURISMO_UQ")
public class Cliente {

    @Id
    @Column(name = "ID_CLIENTE")
    private Long idCliente;

    @Column(name = "IDENTIFICACION", nullable = false, length = 30)
    private String identificacion;

    @Column(name = "NOMBRES", nullable = false, length = 80)
    private String nombres;

    @Column(name = "APELLIDOS", nullable = false, length = 80)
    private String apellidos;

    @Column(name = "EMAIL", length = 120)
    private String email;

    @Column(name = "TELEFONO", length = 30)
    private String telefono;

    @Transient
    public String getNombreCompleto() {
        return nombres + " " + apellidos;
    }
}
