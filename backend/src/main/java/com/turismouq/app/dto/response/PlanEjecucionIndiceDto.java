package com.turismouq.app.dto.response;

import java.math.BigDecimal;

public record PlanEjecucionIndiceDto(
    Long idCaso,
    String codigoConsulta,
    String titulo,
    String tipoIndice,
    String nombreIndice,
    String ddlIndice,
    String sqlConsulta,
    String operacionAntes,
    Long costoAntes,
    Long cardinalidadAntes,
    Long bytesAntes,
    BigDecimal tiempoMsAntes,
    String planTextoAntes,
    String operacionDespues,
    Long costoDespues,
    Long cardinalidadDespues,
    Long bytesDespues,
    BigDecimal tiempoMsDespues,
    String planTextoDespues,
    BigDecimal reduccionCostoPct,
    boolean esCasoNegativo,
    String explicacionTecnica
) {}
