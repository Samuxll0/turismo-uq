-- ========================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- ENTREGA 2: ESPECIFICACION DEL PAQUETE PK_TURISMO_RESERVAS
-- ARCHIVO: 02_pkg_turismo_reservas_spec.sql
-- ========================================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = TURISMO_UQ;

CREATE OR REPLACE PACKAGE TURISMO_UQ.PKG_TURISMO_RESERVAS AS

    /**
     * Calcula el valor total de una estadia iterando noche por noche entre
     * p_fecha_in y p_fecha_out - 1. Aplica la tarifa de Temporada Alta si la noche
     * cae en una ventana definida en PERIODO_TEMPORADA; de lo contrario, aplica Temporada Baja.
     *
     * @param p_id_habitacion Identificador unico de la habitacion
     * @param p_fecha_in      Fecha de inicio (Check-in)
     * @param p_fecha_out     Fecha de salida (Check-out)
     * @return                Valor total acumulado de la estadia
     * @throws ORA-20001      Si p_fecha_out <= p_fecha_in
     * @throws ORA-20004      Si la habitacion no existe o no tiene tarifas configuradas
     */
    FUNCTION fn_valor_estadia(
        p_id_habitacion IN NUMBER,
        p_fecha_in      IN DATE,
        p_fecha_out     IN DATE
    ) RETURN NUMBER;

    /**
     * Realiza el proceso integral y transaccional de registro de una reserva.
     * Valida consistencia de fechas, capacidad maxima de la habitacion y solapamiento.
     * Calcula el total mediante fn_valor_estadia e inserta en RESERVA y RESERVA_HABITACION.
     *
     * @param p_id_cliente    Identificador del cliente titular
     * @param p_id_habitacion Identificador de la habitacion a reservar
     * @param p_fecha_in      Fecha de ingreso (Check-in)
     * @param p_fecha_out     Fecha de salida (Check-out)
     * @param p_num_huespedes Numero de personas que ocuparan la habitacion
     * @param o_id_reserva    Parametro de salida con el ID de la reserva generada
     * @param o_total         Parametro de salida con el monto total liquidado
     * @throws ORA-20001      Si check-out es anterior o igual al check-in
     * @throws ORA-20002      Si el numero de huespedes excede la capacidad maxima
     * @throws ORA-20003      Si la habitacion no esta disponible por solapamiento
     * @throws ORA-20004      Si la habitacion no existe
     * @throws ORA-20005      Si el cliente no existe
     */
    PROCEDURE sp_crear_reserva(
        p_id_cliente    IN NUMBER,
        p_id_habitacion IN NUMBER,
        p_fecha_in      IN DATE,
        p_fecha_out     IN DATE,
        p_num_huespedes IN NUMBER,
        o_id_reserva    OUT NUMBER,
        o_total         OUT NUMBER
    );

    /**
     * Realiza la liquidacion economica mensual consolidada por alojamiento,
     * calculando ingresos por concepto de hospedaje y servicios adicionales.
     * Persiste los resultados en LIQUIDACION_MENSUAL_HISTORICO y retorna
     * un cursor abierto para consumo de aplicaciones externas o tableros de control.
     *
     * @param p_mes            Mes a liquidar (1 - 12)
     * @param p_anio           Anio calendario (ej. 2024, 2025, 2026)
     * @param p_id_alojamiento Filtro opcional por alojamiento especifico (NULL para todos)
     * @param o_resultado      Cursor referencial (SYS_REFCURSOR) con el detalle liquidado
     * @throws ORA-20005      Si mes o anio estan fuera de limites validos
     */
    PROCEDURE sp_liquidacion_mensual(
        p_mes            IN NUMBER,
        p_anio           IN NUMBER,
        p_id_alojamiento IN NUMBER DEFAULT NULL,
        o_resultado      OUT SYS_REFCURSOR
    );

END PKG_TURISMO_RESERVAS;
/
