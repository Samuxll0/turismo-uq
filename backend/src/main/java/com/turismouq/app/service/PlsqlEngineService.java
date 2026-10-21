package com.turismouq.app.service;

import com.turismouq.app.dto.request.CotizarRequestDto;
import com.turismouq.app.dto.request.CrearReservaRequestDto;
import com.turismouq.app.dto.response.CotizacionResponseDto;
import com.turismouq.app.dto.response.LiquidacionItemDto;
import com.turismouq.app.dto.response.ReservaResponseDto;
import com.turismouq.app.entity.Cliente;
import com.turismouq.app.entity.Habitacion;
import com.turismouq.app.entity.Tarifa;
import com.turismouq.app.exception.ApiException;
import com.turismouq.app.repository.ClienteRepository;
import com.turismouq.app.repository.HabitacionRepository;
import com.turismouq.app.repository.TarifaRepository;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.sql.CallableStatement;
import java.sql.Date;
import java.sql.ResultSet;
import java.sql.Types;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;

@Service
public class PlsqlEngineService {

    private final JdbcTemplate jdbcTemplate;
    private final HabitacionRepository habitacionRepository;
    private final ClienteRepository clienteRepository;
    private final TarifaRepository tarifaRepository;

    public PlsqlEngineService(JdbcTemplate jdbcTemplate,
                              HabitacionRepository habitacionRepository,
                              ClienteRepository clienteRepository,
                              TarifaRepository tarifaRepository) {
        this.jdbcTemplate = jdbcTemplate;
        this.habitacionRepository = habitacionRepository;
        this.clienteRepository = clienteRepository;
        this.tarifaRepository = tarifaRepository;
    }

    /**
     * Invoca la función PL/SQL PKG_TURISMO_RESERVAS.fn_valor_estadia
     */
    public CotizacionResponseDto cotizarEstadia(CotizarRequestDto dto) {
        Habitacion hab = habitacionRepository.findById(dto.idHabitacion())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "ERR_HABITACION_NO_EXISTE",
                        "No se encontró la habitación con ID " + dto.idHabitacion()));

        BigDecimal tarifaBaja = tarifaRepository.findByHabitacionIdHabitacionAndIdTemporada(dto.idHabitacion(), 1L)
                .map(Tarifa::getPrecioNoche)
                .orElse(BigDecimal.ZERO);

        BigDecimal tarifaAlta = tarifaRepository.findByHabitacionIdHabitacionAndIdTemporada(dto.idHabitacion(), 2L)
                .map(Tarifa::getPrecioNoche)
                .orElse(BigDecimal.ZERO);

        BigDecimal total = jdbcTemplate.execute((java.sql.Connection conn) -> {
            String callSql = "{ ? = call TURISMO_UQ.PKG_TURISMO_RESERVAS.fn_valor_estadia(?, ?, ?) }";
            try (CallableStatement cs = conn.prepareCall(callSql)) {
                cs.registerOutParameter(1, Types.NUMERIC);
                cs.setLong(2, dto.idHabitacion());
                cs.setDate(3, Date.valueOf(dto.fechaIn()));
                cs.setDate(4, Date.valueOf(dto.fechaOut()));
                cs.execute();
                return cs.getBigDecimal(1);
            }
        });

        long noches = ChronoUnit.DAYS.between(dto.fechaIn(), dto.fechaOut());

        return new CotizacionResponseDto(
                hab.getIdHabitacion(),
                hab.getNumeroNombre(),
                hab.getAlojamiento().getNombre(),
                dto.fechaIn(),
                dto.fechaOut(),
                noches,
                tarifaBaja,
                tarifaAlta,
                total
        );
    }

    /**
     * Invoca el procedimiento PL/SQL PKG_TURISMO_RESERVAS.sp_crear_reserva
     */
    @Transactional
    public ReservaResponseDto crearReserva(CrearReservaRequestDto dto) {
        Habitacion hab = habitacionRepository.findById(dto.idHabitacion())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "ERR_HABITACION_NO_EXISTE",
                        "No se encontró la habitación con ID " + dto.idHabitacion()));

        Cliente cliente = clienteRepository.findById(dto.idCliente())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "ERR_CLIENTE_NO_EXISTE",
                        "No se encontró el cliente con ID " + dto.idCliente()));

        return jdbcTemplate.execute((java.sql.Connection conn) -> {
            String callSql = "{ call TURISMO_UQ.PKG_TURISMO_RESERVAS.sp_crear_reserva(?, ?, ?, ?, ?, ?, ?) }";
            try (CallableStatement cs = conn.prepareCall(callSql)) {
                cs.setLong(1, dto.idCliente());
                cs.setLong(2, dto.idHabitacion());
                cs.setDate(3, Date.valueOf(dto.fechaIn()));
                cs.setDate(4, Date.valueOf(dto.fechaOut()));
                cs.setInt(5, dto.numHuespedes());
                cs.registerOutParameter(6, Types.NUMERIC); // o_id_reserva
                cs.registerOutParameter(7, Types.NUMERIC); // o_total

                cs.execute();

                Long idReserva = cs.getLong(6);
                BigDecimal total = cs.getBigDecimal(7);

                return new ReservaResponseDto(
                        idReserva,
                        cliente.getIdCliente(),
                        cliente.getNombreCompleto(),
                        hab.getIdHabitacion(),
                        hab.getNumeroNombre(),
                        hab.getAlojamiento().getNombre(),
                        dto.fechaIn(),
                        dto.fechaOut(),
                        total,
                        "CONFIRMADA"
                );
            }
        });
    }

    /**
     * Invoca el procedimiento PL/SQL PKG_TURISMO_RESERVAS.sp_liquidacion_mensual
     */
    public List<LiquidacionItemDto> ejecutarLiquidacionMensual(int mes, int anio, Long idAlojamiento) {
        return jdbcTemplate.execute((java.sql.Connection conn) -> {
            String callSql = "{ call TURISMO_UQ.PKG_TURISMO_RESERVAS.sp_liquidacion_mensual(?, ?, ?, ?) }";
            try (CallableStatement cs = conn.prepareCall(callSql)) {
                cs.setInt(1, mes);
                cs.setInt(2, anio);
                if (idAlojamiento != null) {
                    cs.setLong(3, idAlojamiento);
                } else {
                    cs.setNull(3, Types.NUMERIC);
                }
                cs.registerOutParameter(4, -10); // OracleTypes.CURSOR (-10)

                cs.execute();

                List<LiquidacionItemDto> resultado = new ArrayList<>();
                try (ResultSet rs = (ResultSet) cs.getObject(4)) {
                    if (rs != null) {
                        while (rs.next()) {
                            resultado.add(new LiquidacionItemDto(
                                    rs.getInt("ANIO"),
                                    rs.getInt("MES"),
                                    rs.getLong("ID_ALOJAMIENTO"),
                                    rs.getString("NOMBRE_ALOJAMIENTO"),
                                    rs.getLong("TOTAL_RESERVAS"),
                                    rs.getBigDecimal("INGRESO_HOSPEDAJE"),
                                    rs.getBigDecimal("INGRESO_SERVICIOS"),
                                    rs.getBigDecimal("INGRESO_TOTAL"),
                                    rs.getBigDecimal("INGRESO_TOTAL").multiply(new BigDecimal("0.10")),
                                    rs.getBigDecimal("INGRESO_TOTAL").multiply(new BigDecimal("0.90"))
                            ));
                        }
                    }
                }
                return resultado;
            }
        });
    }
}
