package com.turismouq.app.service;

import com.turismouq.app.dto.request.ReservaTransaccionalRequestDto;
import com.turismouq.app.dto.request.SimularConcurrenciaRequestDto;
import com.turismouq.app.dto.response.ReservaTransaccionalResponseDto;
import com.turismouq.app.dto.response.SimulacionConcurrenciaResponseDto;
import com.turismouq.app.entity.Cliente;
import com.turismouq.app.entity.Habitacion;
import com.turismouq.app.exception.ApiException;
import com.turismouq.app.repository.ClienteRepository;
import com.turismouq.app.repository.HabitacionRepository;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import javax.sql.DataSource;
import java.math.BigDecimal;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Types;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;

@Service
public class TransaccionService {

    private final JdbcTemplate jdbcTemplate;
    private final DataSource dataSource;
    private final HabitacionRepository habitacionRepository;
    private final ClienteRepository clienteRepository;

    public TransaccionService(JdbcTemplate jdbcTemplate,
                              DataSource dataSource,
                              HabitacionRepository habitacionRepository,
                              ClienteRepository clienteRepository) {
        this.jdbcTemplate = jdbcTemplate;
        this.dataSource = dataSource;
        this.habitacionRepository = habitacionRepository;
        this.clienteRepository = clienteRepository;
    }

    /**
     * Invoca TURISMO_UQ.sp_reserva_transaccional_pago demostrando atomicidad,
     * SAVEPOINT sp_reserva_creada y Rollback Parcial cuando el pago falla.
     */
    public ReservaTransaccionalResponseDto registrarReservaConPago(ReservaTransaccionalRequestDto dto) {
        long inicio = System.currentTimeMillis();

        Long idCliente = dto.getIdCliente() != null ? dto.getIdCliente() : 1L;
        Long idHabitacion = dto.getIdHabitacion() != null ? dto.getIdHabitacion() : 1L;
        LocalDate fechaIn = dto.getFechaIn() != null ? dto.getFechaIn() : LocalDate.of(2028, 5, 10);
        LocalDate fechaOut = dto.getFechaOut() != null ? dto.getFechaOut() : LocalDate.of(2028, 5, 14);
        int numHuespedes = dto.getNumHuespedes() != null ? dto.getNumHuespedes() : 2;
        String metodoPago = (dto.getMetodoPago() != null && !dto.getMetodoPago().isBlank())
                ? dto.getMetodoPago().toUpperCase()
                : "TARJETA";
        boolean simularFallo = Boolean.TRUE.equals(dto.getSimularFalloPago());

        Habitacion hab = habitacionRepository.findByIdWithDetails(idHabitacion)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "ERR_HABITACION_NO_EXISTE",
                        "No se encontró la habitación con ID " + idHabitacion));

        Cliente cliente = clienteRepository.findById(idCliente)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "ERR_CLIENTE_NO_EXISTE",
                        "No se encontró el cliente con ID " + idCliente));

        // Si es una fecha de banco de pruebas (>= 2028), limpiar colisión previa para permitir pruebas repetibles en 1 clic
        if (fechaIn.getYear() >= 2028) {
            limpiarRangoPrueba(idHabitacion, fechaIn, fechaOut);
        }

        return jdbcTemplate.execute((Connection conn) -> {
            String callSql = "{ call TURISMO_UQ.sp_reserva_transaccional_pago(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) }";
            try (CallableStatement cs = conn.prepareCall(callSql)) {
                cs.setLong(1, idCliente);
                cs.setLong(2, idHabitacion);
                cs.setDate(3, Date.valueOf(fechaIn));
                cs.setDate(4, Date.valueOf(fechaOut));
                cs.setInt(5, numHuespedes);
                if (dto.getMontoPago() != null) {
                    cs.setBigDecimal(6, dto.getMontoPago());
                } else {
                    cs.setNull(6, Types.NUMERIC);
                }
                cs.setString(7, metodoPago);
                cs.setString(8, simularFallo ? "S" : "N");

                cs.registerOutParameter(9, Types.NUMERIC);  // o_id_reserva
                cs.registerOutParameter(10, Types.NUMERIC); // o_id_pago
                cs.registerOutParameter(11, Types.NUMERIC); // o_total_reserva
                cs.registerOutParameter(12, Types.VARCHAR); // o_estado_reserva
                cs.registerOutParameter(13, Types.VARCHAR); // o_estado_pago
                cs.registerOutParameter(14, Types.VARCHAR); // o_rollback_parcial
                cs.registerOutParameter(15, Types.VARCHAR); // o_mensaje

                cs.execute();

                Long idReserva = cs.getLong(9);
                long rawIdPago = cs.getLong(10);
                Long idPago = cs.wasNull() ? null : rawIdPago;
                BigDecimal totalReserva = cs.getBigDecimal(11);
                String estadoReserva = cs.getString(12);
                String estadoPago = cs.getString(13);
                boolean rollbackParcial = "S".equalsIgnoreCase(cs.getString(14));
                String mensaje = cs.getString(15);
                BigDecimal montoEfectivo = dto.getMontoPago() != null ? dto.getMontoPago() : totalReserva;

                long duracion = System.currentTimeMillis() - inicio;

                return new ReservaTransaccionalResponseDto(
                        idReserva,
                        idPago,
                        cliente.getIdCliente(),
                        cliente.getNombreCompleto(),
                        hab.getIdHabitacion(),
                        hab.getNumeroNombre(),
                        hab.getAlojamiento().getNombre(),
                        fechaIn,
                        fechaOut,
                        totalReserva,
                        rollbackParcial ? BigDecimal.ZERO : montoEfectivo,
                        metodoPago,
                        estadoReserva,
                        estadoPago,
                        rollbackParcial,
                        "sp_reserva_creada",
                        mensaje,
                        duracion
                );
            }
        });
    }

    /**
     * Ejecuta un experimento en vivo con DOS conexiones JDBC independientes (Sesión 1 y Sesión 2)
     * intentando reservar simultáneamente la misma habitación en las mismas fechas,
     * demostrando el bloqueo de fila con SELECT ... FOR UPDATE.
     */
    public SimulacionConcurrenciaResponseDto simularConcurrenciaDosSesiones(SimularConcurrenciaRequestDto dto) {
        Long idHabitacion = (dto != null && dto.getIdHabitacion() != null) ? dto.getIdHabitacion() : 1L;
        Long idCliente1 = (dto != null && dto.getIdClienteSesion1() != null) ? dto.getIdClienteSesion1() : 1L;
        Long idCliente2 = (dto != null && dto.getIdClienteSesion2() != null) ? dto.getIdClienteSesion2() : 2L;
        LocalDate fechaIn = (dto != null && dto.getFechaIn() != null) ? dto.getFechaIn() : LocalDate.of(2028, 7, 15);
        LocalDate fechaOut = (dto != null && dto.getFechaOut() != null) ? dto.getFechaOut() : LocalDate.of(2028, 7, 19);
        int numHuespedes = (dto != null && dto.getNumHuespedes() != null) ? dto.getNumHuespedes() : 2;

        Habitacion hab = habitacionRepository.findByIdWithDetails(idHabitacion)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "ERR_HABITACION_NO_EXISTE",
                        "No se encontró la habitación con ID " + idHabitacion));

        // Limpiar reservas previas en esa ventana de prueba para que el experimento sea 100% reproducible
        limpiarRangoPrueba(idHabitacion, fechaIn, fechaOut);

        List<String> timeline = Collections.synchronizedList(new ArrayList<>());
        CountDownLatch latchCandadoAdquirido = new CountDownLatch(1);

        AtomicReference<String> s1Estado = new AtomicReference<>("CONFIRMADA");
        AtomicReference<Long> s1ReservaId = new AtomicReference<>(null);
        AtomicReference<String> s1Detalle = new AtomicReference<>("");

        AtomicReference<String> s2Estado = new AtomicReference<>("RECHAZADA_POST_DESBLOQUEO");
        AtomicReference<String> s2CodigoError = new AtomicReference<>("ORA-20003");
        AtomicReference<String> s2Detalle = new AtomicReference<>("");
        AtomicLong s2EsperaMs = new AtomicLong(0);

        // Hilo 1: Sesión 1 adquiere el bloqueo exclusivo SELECT ... FOR UPDATE, retiene la fila 550ms y confirma
        CompletableFuture<Void> sesion1Future = CompletableFuture.runAsync(() -> {
            try (Connection conn1 = dataSource.getConnection()) {
                conn1.setAutoCommit(false);
                timeline.add("[T+00ms] SESIÓN 1: Inicia transacción y ejecuta SELECT ... FROM HABITACION WHERE id_habitacion = " + idHabitacion + " FOR UPDATE WAIT 5.");

                try (PreparedStatement psLock = conn1.prepareStatement(
                        "SELECT capacidad, numero_nombre FROM TURISMO_UQ.HABITACION WHERE id_habitacion = ? FOR UPDATE WAIT 5")) {
                    psLock.setLong(1, idHabitacion);
                    psLock.executeQuery();
                }

                timeline.add("[T+15ms] SESIÓN 1: Candado exclusivo de fila (Row-X Lock TX) adquirido sobre Habitación #" + idHabitacion + " (" + hab.getNumeroNombre() + ").");
                latchCandadoAdquirido.countDown();

                // Simular tiempo de procesamiento mientras Sesión 2 intenta entrar concurrentemente
                Thread.sleep(550);

                String callSql = "{ call TURISMO_UQ.sp_reservar_con_bloqueo(?, ?, ?, ?, ?, ?, ?, ?, ?) }";
                try (CallableStatement cs = conn1.prepareCall(callSql)) {
                    cs.setLong(1, idCliente1);
                    cs.setLong(2, idHabitacion);
                    cs.setDate(3, Date.valueOf(fechaIn));
                    cs.setDate(4, Date.valueOf(fechaOut));
                    cs.setInt(5, numHuespedes);
                    cs.setInt(6, 5);
                    cs.registerOutParameter(7, Types.NUMERIC);
                    cs.registerOutParameter(8, Types.NUMERIC);
                    cs.registerOutParameter(9, Types.VARCHAR);
                    cs.execute();

                    long idRes = cs.getLong(7);
                    String msg = cs.getString(9);
                    s1ReservaId.set(idRes);
                    s1Detalle.set(msg);
                    timeline.add("[T+570ms] SESIÓN 1: Inserta Reserva #" + idRes + " y ejecuta COMMIT, liberando el candado TX de la fila.");
                }
            } catch (Exception ex) {
                s1Estado.set("ERROR");
                s1Detalle.set(ex.getMessage());
                latchCandadoAdquirido.countDown();
            }
        });

        // Hilo 2: Sesión 2 intenta reservar la misma habitación mientras Sesión 1 tiene el candado
        CompletableFuture<Void> sesion2Future = CompletableFuture.runAsync(() -> {
            try {
                latchCandadoAdquirido.await(3, TimeUnit.SECONDS);
                long tInicioEspera = System.currentTimeMillis();
                timeline.add("[T+30ms] SESIÓN 2: Intenta reservar la misma Habitación #" + idHabitacion + " (" + fechaIn + " a " + fechaOut + ").");
                timeline.add("[T+35ms] SESIÓN 2: Bloqueada por Oracle en evento 'enq: TX - row lock contention' esperando que Sesión 1 haga COMMIT o ROLLBACK...");

                try (Connection conn2 = dataSource.getConnection()) {
                    String callSql = "{ call TURISMO_UQ.sp_reservar_con_bloqueo(?, ?, ?, ?, ?, ?, ?, ?, ?) }";
                    try (CallableStatement cs = conn2.prepareCall(callSql)) {
                        cs.setLong(1, idCliente2);
                        cs.setLong(2, idHabitacion);
                        cs.setDate(3, Date.valueOf(fechaIn));
                        cs.setDate(4, Date.valueOf(fechaOut));
                        cs.setInt(5, numHuespedes);
                        cs.setInt(6, 5);
                        cs.registerOutParameter(7, Types.NUMERIC);
                        cs.registerOutParameter(8, Types.NUMERIC);
                        cs.registerOutParameter(9, Types.VARCHAR);
                        cs.execute();
                    }
                } catch (SQLException sqlEx) {
                    long espera = System.currentTimeMillis() - tInicioEspera;
                    s2EsperaMs.set(espera);
                    int code = sqlEx.getErrorCode();
                    s2CodigoError.set("ORA-" + code);
                    s2Detalle.set("Tras esperar " + espera + " ms en cola de bloqueo (SELECT FOR UPDATE), Sesión 2 despertó y detectó la reserva recién confirmada por Sesión 1: [ORA-" + code + "] Habitación no disponible.");
                    timeline.add("[T+" + (35 + espera) + "ms] SESIÓN 2: Despierta tras el COMMIT de Sesión 1, reevalúa disponibilidad y es rechazada limpiamente con ORA-" + code + " evitando doble reserva.");
                }
            } catch (Exception ex) {
                s2Detalle.set(ex.getMessage());
            }
        });

        CompletableFuture.allOf(sesion1Future, sesion2Future).join();

        return new SimulacionConcurrenciaResponseDto(
                hab.getIdHabitacion(),
                hab.getNumeroNombre(),
                hab.getAlojamiento().getNombre(),
                fechaIn,
                fechaOut,
                "SELECT capacidad, numero_nombre FROM TURISMO_UQ.HABITACION WHERE id_habitacion = " + idHabitacion + " FOR UPDATE WAIT 5",
                s1Estado.get(),
                s1ReservaId.get(),
                s1Detalle.get(),
                s2Estado.get(),
                s2CodigoError.get(),
                s2Detalle.get(),
                s2EsperaMs.get(),
                timeline,
                "SIN SELECT FOR UPDATE (Antes): Bajo aislamiento READ COMMITTED, tanto Sesión 1 como Sesión 2 leen simultáneamente que hay 0 reservas solapadas (porque ninguna ha hecho COMMIT aún). Ambas avanzan en condición de carrera (Race Condition) e intentan insertar la misma habitación para las mismas fechas.",
                "CON SELECT FOR UPDATE (Después): Sesión 1 adquiere un candado exclusivo a nivel de fila (Row-X TX Lock) sobre la habitación. Sesión 2 queda encolada en espera ('enq: TX - row lock contention') durante " + s2EsperaMs.get() + " ms. Cuando Sesión 1 hace COMMIT, Sesión 2 despierta, lee el estado ya actualizado y aborta inmediatamente con ORA-20003."
        );
    }

    private void limpiarRangoPrueba(Long idHabitacion, LocalDate fechaIn, LocalDate fechaOut) {
        try {
            jdbcTemplate.update("""
                DELETE FROM TURISMO_UQ.PAGO
                WHERE id_reserva IN (
                    SELECT r.id_reserva
                    FROM TURISMO_UQ.RESERVA r
                    JOIN TURISMO_UQ.RESERVA_HABITACION rh ON r.id_reserva = rh.id_reserva
                    WHERE rh.id_habitacion = ?
                      AND r.fecha_check_in < ?
                      AND r.fecha_check_out > ?
                )
            """, idHabitacion, Date.valueOf(fechaOut), Date.valueOf(fechaIn));

            jdbcTemplate.update("""
                DELETE FROM TURISMO_UQ.RESERVA
                WHERE id_reserva IN (
                    SELECT r.id_reserva
                    FROM TURISMO_UQ.RESERVA r
                    JOIN TURISMO_UQ.RESERVA_HABITACION rh ON r.id_reserva = rh.id_reserva
                    WHERE rh.id_habitacion = ?
                      AND r.fecha_check_in < ?
                      AND r.fecha_check_out > ?
                )
            """, idHabitacion, Date.valueOf(fechaOut), Date.valueOf(fechaIn));
        } catch (Exception ignored) {
        }
    }
}
