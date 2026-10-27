package com.turismouq.app.dto.request;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.math.BigDecimal;

public class GuardarTarifaRequestDto {

    @JsonProperty("id_habitacion")
    @JsonAlias({"idHabitacion", "id_habitacion"})
    private Long idHabitacion;

    @JsonProperty("precio_baja")
    @JsonAlias({"precioBaja", "precio_baja"})
    private BigDecimal precioBaja;

    @JsonProperty("precio_alta")
    @JsonAlias({"precioAlta", "precio_alta"})
    private BigDecimal precioAlta;

    public GuardarTarifaRequestDto() {}

    public GuardarTarifaRequestDto(Long idHabitacion, BigDecimal precioBaja, BigDecimal precioAlta) {
        this.idHabitacion = idHabitacion;
        this.precioBaja = precioBaja;
        this.precioAlta = precioAlta;
    }

    public Long idHabitacion() {
        return idHabitacion;
    }

    public Long getIdHabitacion() {
        return idHabitacion;
    }

    public void setIdHabitacion(Long idHabitacion) {
        this.idHabitacion = idHabitacion;
    }

    public BigDecimal precioBaja() {
        return precioBaja;
    }

    public BigDecimal getPrecioBaja() {
        return precioBaja;
    }

    public void setPrecioBaja(BigDecimal precioBaja) {
        this.precioBaja = precioBaja;
    }

    public BigDecimal precioAlta() {
        return precioAlta;
    }

    public BigDecimal getPrecioAlta() {
        return precioAlta;
    }

    public void setPrecioAlta(BigDecimal precioAlta) {
        this.precioAlta = precioAlta;
    }
}
