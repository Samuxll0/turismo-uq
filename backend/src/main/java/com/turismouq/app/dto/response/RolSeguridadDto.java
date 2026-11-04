package com.turismouq.app.dto.response;

public record RolSeguridadDto(
    Long idRol,
    String nombreRol,
    String tituloRol,
    String accesoTablasBase,
    String objetosPermitidos,
    String privilegiosDml,
    boolean aislamientoVistas,
    String justificacion
) {}
