package com.turismouq.app.dto.request;

public record RegistroUsuarioRequestDto(
        String username,
        String password,
        String rol
) {
}
