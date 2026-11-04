package com.turismouq.app.dto.request;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.LocalDate;

public class SimularConcurrenciaRequestDto {

    @JsonProperty("id_habitacion")
    @JsonAlias({"idHabitacion", "id_habitacion"})
    private Long idHabitacion;

    @JsonProperty("id_cliente_sesion1")
    @JsonAlias({"idClienteSesion1", "id_cliente_sesion1"})
    private Long idClienteSesion1;

    @JsonProperty("id_cliente_sesion2")
    @JsonAlias({"idClienteSesion2", "id_cliente_sesion2"})
    private Long idClienteSesion2;

    @JsonProperty("fecha_in")
    @JsonAlias({"fechaIn", "fecha_in"})
    private LocalDate fechaIn;

    @JsonProperty("fecha_out")
    @JsonAlias({"fechaOut", "fecha_out"})
    private LocalDate fechaOut;

    @JsonProperty("num_huespedes")
    @JsonAlias({"numHuespedes", "num_huespedes"})
    private Integer numHuespedes;

    public SimularConcurrenciaRequestDto() {}

    public Long getIdHabitacion() { return idHabitacion; }
    public void setIdHabitacion(Long idHabitacion) { this.idHabitacion = idHabitacion; }

    public Long getIdClienteSesion1() { return idClienteSesion1; }
    public void setIdClienteSesion1(Long idClienteSesion1) { this.idClienteSesion1 = idClienteSesion1; }

    public Long getIdClienteSesion2() { return idClienteSesion2; }
    public void setIdClienteSesion2(Long idClienteSesion2) { this.idClienteSesion2 = idClienteSesion2; }

    public LocalDate getFechaIn() { return fechaIn; }
    public void setFechaIn(LocalDate fechaIn) { this.fechaIn = fechaIn; }

    public LocalDate getFechaOut() { return fechaOut; }
    public void setFechaOut(LocalDate fechaOut) { this.fechaOut = fechaOut; }

    public Integer getNumHuespedes() { return numHuespedes; }
    public void setNumHuespedes(Integer numHuespedes) { this.numHuespedes = numHuespedes; }
}
