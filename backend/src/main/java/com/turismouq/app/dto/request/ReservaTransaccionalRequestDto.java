package com.turismouq.app.dto.request;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.math.BigDecimal;
import java.time.LocalDate;

public class ReservaTransaccionalRequestDto {

    @JsonProperty("id_cliente")
    @JsonAlias({"idCliente", "id_cliente"})
    private Long idCliente;

    @JsonProperty("id_habitacion")
    @JsonAlias({"idHabitacion", "id_habitacion"})
    private Long idHabitacion;

    @JsonProperty("fecha_in")
    @JsonAlias({"fechaIn", "fecha_in", "fechaCheckIn", "fecha_check_in"})
    private LocalDate fechaIn;

    @JsonProperty("fecha_out")
    @JsonAlias({"fechaOut", "fecha_out", "fechaCheckOut", "fecha_check_out"})
    private LocalDate fechaOut;

    @JsonProperty("num_huespedes")
    @JsonAlias({"numHuespedes", "num_huespedes"})
    private Integer numHuespedes;

    @JsonProperty("monto_pago")
    @JsonAlias({"montoPago", "monto_pago"})
    private BigDecimal montoPago;

    @JsonProperty("metodo_pago")
    @JsonAlias({"metodoPago", "metodo_pago"})
    private String metodoPago;

    @JsonProperty("simular_fallo_pago")
    @JsonAlias({"simularFalloPago", "simular_fallo_pago"})
    private Boolean simularFalloPago;

    public ReservaTransaccionalRequestDto() {}

    public Long getIdCliente() { return idCliente; }
    public void setIdCliente(Long idCliente) { this.idCliente = idCliente; }

    public Long getIdHabitacion() { return idHabitacion; }
    public void setIdHabitacion(Long idHabitacion) { this.idHabitacion = idHabitacion; }

    public LocalDate getFechaIn() { return fechaIn; }
    public void setFechaIn(LocalDate fechaIn) { this.fechaIn = fechaIn; }

    public LocalDate getFechaOut() { return fechaOut; }
    public void setFechaOut(LocalDate fechaOut) { this.fechaOut = fechaOut; }

    public Integer getNumHuespedes() { return numHuespedes; }
    public void setNumHuespedes(Integer numHuespedes) { this.numHuespedes = numHuespedes; }

    public BigDecimal getMontoPago() { return montoPago; }
    public void setMontoPago(BigDecimal montoPago) { this.montoPago = montoPago; }

    public String getMetodoPago() { return metodoPago; }
    public void setMetodoPago(String metodoPago) { this.metodoPago = metodoPago; }

    public Boolean getSimularFalloPago() { return simularFalloPago; }
    public void setSimularFalloPago(Boolean simularFalloPago) { this.simularFalloPago = simularFalloPago; }
}
