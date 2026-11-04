package com.turismouq.app.dto.response;

public record PerfilLimiteDto(
    Long idParametro,
    String nombrePerfil,
    String recurso,
    String valorLimite,
    String unidad,
    String proposito
) {}
