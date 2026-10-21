package com.turismouq.app.exception;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.sql.SQLException;
import java.time.LocalDateTime;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ErrorResponse> handleApiException(ApiException ex, HttpServletRequest request) {
        ErrorResponse body = new ErrorResponse(
                LocalDateTime.now(),
                ex.getStatus().value(),
                ex.getStatus().getReasonPhrase(),
                ex.getErrorCode(),
                ex.getMessage(),
                request.getRequestURI()
        );
        return new ResponseEntity<>(body, ex.getStatus());
    }

    @ExceptionHandler(SQLException.class)
    public ResponseEntity<ErrorResponse> handleSQLException(SQLException ex, HttpServletRequest request) {
        int errorCode = ex.getErrorCode();
        String message = ex.getMessage();
        HttpStatus status = HttpStatus.INTERNAL_SERVER_ERROR;
        String code = "ORA_ERROR_" + errorCode;

        // Limpiar el mensaje de Oracle para la UI
        if (message != null && message.contains(":")) {
            int firstColon = message.indexOf(':');
            int secondColon = message.indexOf(':', firstColon + 1);
            if (secondColon != -1) {
                int nextOra = message.indexOf("ORA-", secondColon);
                if (nextOra != -1) {
                    message = message.substring(firstColon + 1, nextOra).trim();
                } else {
                    message = message.substring(firstColon + 1).trim();
                }
            }
        }

        switch (errorCode) {
            case 20001 -> {
                status = HttpStatus.BAD_REQUEST;
                code = "ERR_FECHAS_INVALIDAS";
            }
            case 20002 -> {
                status = HttpStatus.UNPROCESSABLE_ENTITY;
                code = "ERR_CAPACIDAD_EXCEDIDA";
            }
            case 20003 -> {
                status = HttpStatus.CONFLICT;
                code = "ERR_HABITACION_OCUPADA";
            }
            case 20004 -> {
                status = HttpStatus.NOT_FOUND;
                code = "ERR_HABITACION_NO_EXISTE";
            }
            case 20005 -> {
                status = HttpStatus.BAD_REQUEST;
                code = "ERR_CLIENTE_NO_EXISTE";
            }
            default -> {
                if (errorCode >= 20000 && errorCode <= 20999) {
                    status = HttpStatus.BAD_REQUEST;
                    code = "ERR_REGLA_NEGOCIO";
                }
            }
        }

        ErrorResponse body = new ErrorResponse(
                LocalDateTime.now(),
                status.value(),
                status.getReasonPhrase(),
                code,
                message,
                request.getRequestURI()
        );
        return new ResponseEntity<>(body, status);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationException(MethodArgumentNotValidException ex, HttpServletRequest request) {
        String defaultMsg = ex.getBindingResult().getFieldErrors().stream()
                .map(f -> f.getField() + ": " + f.getDefaultMessage())
                .findFirst()
                .orElse("Datos de petición no válidos");

        ErrorResponse body = new ErrorResponse(
                LocalDateTime.now(),
                HttpStatus.BAD_REQUEST.value(),
                HttpStatus.BAD_REQUEST.getReasonPhrase(),
                "VALIDATION_ERROR",
                defaultMsg,
                request.getRequestURI()
        );
        return new ResponseEntity<>(body, HttpStatus.BAD_REQUEST);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGeneralException(Exception ex, HttpServletRequest request) {
        ErrorResponse body = new ErrorResponse(
                LocalDateTime.now(),
                HttpStatus.INTERNAL_SERVER_ERROR.value(),
                HttpStatus.INTERNAL_SERVER_ERROR.getReasonPhrase(),
                "INTERNAL_SERVER_ERROR",
                ex.getMessage(),
                request.getRequestURI()
        );
        return new ResponseEntity<>(body, HttpStatus.INTERNAL_SERVER_ERROR);
    }
}
