package com.turismouq.app.dto.response;

import java.util.List;

public record UsuarioAutenticadoDto(
        Long id_usuario,
        String username,
        String rol,
        String titulo_rol,
        boolean activo,
        List<String> modulos_permitidos,
        boolean puede_editar_tarifas,
        String mensaje
) {
}
