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

    @Column(name = "DOCUMENTO", nullable = false, length = 25)
    private String documento;

    @Column(name = "NOMBRES", nullable = false, length = 80)
    private String nombres;

    @Column(name = "APELLIDOS", nullable = false, length = 80)
    private String apellidos;

    @Column(name = "CORREO", length = 120)
    private String correo;

    @Column(name = "TELEFONO", length = 25)
    private String telefono;

    @Transient
    public String getNombreCompleto() {
        return nombres + " " + apellidos;
    }

    // Métodos de compatibilidad hacia atrás
    public String getIdentificacion() {
        return documento;
    }

    public void setIdentificacion(String identificacion) {
        this.documento = identificacion;
    }

    public String getEmail() {
        return correo;
    }

    public void setEmail(String email) {
        this.correo = email;
    }
}
