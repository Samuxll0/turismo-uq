import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface CatalogoItem {
  id: number;
  nombre: string;
  descripcion?: string;
  // Campos opcionales para enriquecer tarjetas de alojamiento
  id_municipio?: number;
  nombre_municipio?: string;
  direccion?: string;
  telefono?: string;
  capacidad_total?: number;
  total_habitaciones?: number;
  tarifa_minima?: number;
  imagen_url?: string;
  rating?: number;
}

export interface HabitacionDetalle {
  id_habitacion: number;
  numero_nombre: string;
  capacidad: number;
  tipo_cama: string;
  id_alojamiento: number;
  nombre_alojamiento: string;
  nombre_municipio: string;
  tarifa_baja: number;
  tarifa_alta: number;
}

export interface CotizacionResponse {
  id_habitacion: number;
  nombre_habitacion: string;
  nombre_alojamiento: string;
  fecha_in: string;
  fecha_out: string;
  total_noches: number;
  tarifa_baja: number;
  tarifa_alta: number;
  total_calculado: number;
}

export interface ReservaResponse {
  id_reserva: number;
  id_cliente: number;
  nombre_cliente: string;
  id_habitacion: number;
  nombre_habitacion: string;
  nombre_alojamiento: string;
  fecha_in: string;
  fecha_out: string;
  total: number;
  estado: string;
}

export interface LiquidacionItem {
  anio: number;
  mes: number;
  id_alojamiento: number;
  nombre_alojamiento: string;
  total_reservas: number;
  ingreso_hospedaje: number;
  ingreso_servicios: number;
  ingreso_bruto: number;
  comision_plataforma: number;
  neto_pagar: number;
}

export interface AuditoriaFila {
  id_auditoria: number;
  usuario: string;
  fecha: string;
  id_tarifa: number;
  id_habitacion: number;
  numero_habitacion: string;
  nombre_alojamiento: string;
  nombre_temporada: string;
  precio_anterior: number;
  precio_nuevo: number;
  variacion: number;
  accion: string;
  idAuditoria?: number;
  idTarifa?: number;
  idHabitacion?: number;
  numeroHabitacion?: string;
  nombreAlojamiento?: string;
  nombreTemporada?: string;
  precioAnterior?: number;
  precioNuevo?: number;
}

export interface AuditoriaSentencia {
  idLog: number;
  usuario: string;
  fecha: string;
  accion: string;
  totalFilas: number;
}

export interface AuditoriaResumen {
  totalFilasAuditadas: number;
  totalSentenciasDml: number;
  nombreTrigger: string;
  tipoTrigger: string;
  estadoTrigger: string;
  ultimoUsuario: string;
  ultimaFecha: string;
  ultimasFilas: AuditoriaFila[];
  ultimasSentencias: AuditoriaSentencia[];
}

export interface TarifaDetalle {
  id_habitacion: number;
  numero_habitacion: string;
  capacidad: number;
  tipo_cama: string;
  id_alojamiento: number;
  nombre_alojamiento: string;
  nombre_municipio: string;
  id_tarifa_baja: number;
  precio_baja: number;
  id_tarifa_alta: number;
  precio_alta: number;
  recargo_alta: number;
  porcentaje_recargo: number;
  idHabitacion?: number;
  numeroHabitacion?: string;
  tipoCama?: string;
  idAlojamiento?: number;
  nombreAlojamiento?: string;
  nombreMunicipio?: string;
  idTarifaBaja?: number;
  precioBaja?: number;
  idTarifaAlta?: number;
  precioAlta?: number;
  recargoAlta?: number;
  porcentajeRecargo?: number;
}

export interface PeriodoTemporada {
  idPeriodo: number;
  idTemporada: number;
  nombre: string;
  fechaInicio: string;
  fechaFin: string;
  diasDuracion: number;
}

export interface GuardarTarifaRequest {
  id_habitacion: number;
  precio_baja: number;
  precio_alta?: number;
  idHabitacion?: number;
  precioBaja?: number;
  precioAlta?: number;
}

export interface AnaliticaOcupacion {
  municipio: string;
  ene: number; feb: number; mar: number; abr: number;
  may: number; jun: number; jul: number; ago: number;
  sep: number; oct: number; nov: number; dic: number;
}

export interface AnaliticaJerarquia {
  municipio: string;
  tipo_alojamiento: string;
  temporada: string;
  cantidad_reservas: number;
  ingresos_totales: number;
  g_mun: number;
  g_tipo: number;
  g_temp: number;
}

export interface AnaliticaTop {
  municipio: string;
  posicion_ranking: number;
  alojamiento: string;
  ingresos_alojamiento: number;
}

export interface AnaliticaVariacion {
  anio_mes: string;
  facturacion_actual: number;
  facturacion_mes_anterior: number;
  diferencia_neta: number;
  porcentaje_crecimiento: number;
}

export interface AnaliticaRangoFechas {
  municipio: string;
  reservas_periodo: number;
  total_recaudado: number;
  ticket_promedio: number;
}

export interface AnaliticaMaterializada {
  id_municipio: number;
  municipio: string;
  tipo_alojamiento: string;
  anio_mes: string;
  total_reservas: number;
  total_habitaciones_ocupadas: number;
  facturacion_acumulada: number;
}

export interface AnaliticaUnpivot {
  id_reserva: number;
  mes: string;
  concepto_gasto: string;
  monto: number;
}

export interface AnaliticaClienteClv {
  id_cliente: number;
  nombre_completo: string;
  total_estadias: number;
  total_servicios_contratados: number;
  gasto_historico_total: number;
  ticket_promedio: number;
  pct_facturacion_global: number;
}


export interface TablespaceTabla {
  table_name: string;
  tablespace_name: string;
  num_rows: number;
  size_mb: number;
  blocks: number;
  extents: number;
  status: string;
  descripcion: string;
}

export interface TablespaceIndex {
  index_name: string;
  table_name: string;
  tablespace_name: string;
  status: string;
  uniqueness: string;
  size_mb: number;
}

export interface TablespaceInfo {
  tablespace_name: string;
  status: string;
  extent_management: string;
  allocation_type: string;
  segment_space_management: string;
  block_size_bytes: number;
  initial_size_mb: number;
  autoextend_next_mb: number;
  max_size_mb: number;
  used_bytes: number;
  used_mb: number;
  pct_used_of_initial: number;
  pct_used_of_max: number;
  quota_user: string;
  datafile_name: string;
  datafile_path: string;
  total_filas_historicas: number;
  tablas: TablespaceTabla[];
  indices: TablespaceIndex[];
}

export interface DesgloseNoche {
  fecha: string;
  diaSemana: string;
  esAlta: boolean;
  motivoTemporada: string;
  tarifaNoche: number;
}

export interface ToastNotificacion {
  id: string;
  tipo: 'success' | 'error' | 'warning' | 'info';
  titulo: string;
  mensaje: string;
  codigo?: string;
  duracionMs?: number;
}

@Injectable({
  providedIn: 'root'
})
export class TurismoService {
  private http = inject(HttpClient);
  private baseUrl = 'http://localhost:8080/api';

  // ==========================================
  // Catálogos Base
  // ==========================================
  getMunicipios(): Observable<CatalogoItem[]> {
    return this.http.get<CatalogoItem[]>(`${this.baseUrl}/catalogos/municipios`);
  }

  getAlojamientos(idMunicipio?: number): Observable<CatalogoItem[]> {
    let params = new HttpParams();
    if (idMunicipio) params = params.set('idMunicipio', idMunicipio);
    return this.http.get<CatalogoItem[]>(`${this.baseUrl}/catalogos/alojamientos`, { params });
  }

  getHabitaciones(idAlojamiento?: number): Observable<HabitacionDetalle[]> {
    let params = new HttpParams();
    if (idAlojamiento) params = params.set('idAlojamiento', idAlojamiento);
    return this.http.get<HabitacionDetalle[]>(`${this.baseUrl}/catalogos/habitaciones`, { params });
  }

  getClientes(): Observable<CatalogoItem[]> {
    return this.http.get<CatalogoItem[]>(`${this.baseUrl}/catalogos/clientes`);
  }

  // ==========================================
  // Motor PL/SQL - Procedimientos & Funciones
  // ==========================================
  cotizar(idHabitacion: number, fechaIn: string, fechaOut: string): Observable<CotizacionResponse> {
    return this.http.post<CotizacionResponse>(`${this.baseUrl}/reservas/cotizar`, {
      id_habitacion: idHabitacion,
      fecha_in: fechaIn,
      fecha_out: fechaOut
    });
  }

  crearReserva(
    idCliente: number,
    idHabitacion: number,
    fechaIn: string,
    fechaOut: string,
    numHuespedes: number
  ): Observable<ReservaResponse> {
    return this.http.post<ReservaResponse>(`${this.baseUrl}/reservas`, {
      id_cliente: idCliente,
      id_habitacion: idHabitacion,
      fecha_in: fechaIn,
      fecha_out: fechaOut,
      num_huespedes: numHuespedes
    });
  }

  getLiquidaciones(mes: number, anio: number, idAlojamiento?: number): Observable<LiquidacionItem[]> {
    let params = new HttpParams().set('mes', mes).set('anio', anio);
    if (idAlojamiento) params = params.set('idAlojamiento', idAlojamiento);
    return this.http.get<LiquidacionItem[]>(`${this.baseUrl}/liquidaciones`, { params });
  }

  procesarLiquidacion(mes: number, anio: number, idAlojamiento?: number): Observable<LiquidacionItem[]> {
    let params = new HttpParams().set('mes', mes).set('anio', anio);
    if (idAlojamiento) params = params.set('idAlojamiento', idAlojamiento);
    return this.http.post<LiquidacionItem[]>(`${this.baseUrl}/liquidaciones/procesar`, null, { params });
  }

  limpiarLiquidaciones(): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/liquidaciones/limpiar`);
  }

  // ==========================================
  // Consultas Analíticas BI (PIVOT, ROLLUP, RANK, LAG)
  // ==========================================
  getOcupacionMensual(): Observable<AnaliticaOcupacion[]> {
    return this.http.get<AnaliticaOcupacion[]>(`${this.baseUrl}/analitica/ocupacion-mensual`);
  }

  getIngresosJerarquia(): Observable<AnaliticaJerarquia[]> {
    return this.http.get<AnaliticaJerarquia[]>(`${this.baseUrl}/analitica/ingresos-jerarquia`);
  }

  getTopAlojamientos(): Observable<AnaliticaTop[]> {
    return this.http.get<AnaliticaTop[]>(`${this.baseUrl}/analitica/top-alojamientos`);
  }

  getVariacionMes(): Observable<AnaliticaVariacion[]> {
    return this.http.get<AnaliticaVariacion[]>(`${this.baseUrl}/analitica/variacion-mes`);
  }

  getRangoFechas(fechaInicio: string, fechaFin: string): Observable<AnaliticaRangoFechas[]> {
    let params = new HttpParams()
      .set('fechaInicio', fechaInicio)
      .set('fechaFin', fechaFin);
    return this.http.get<AnaliticaRangoFechas[]>(`${this.baseUrl}/analitica/rango-fechas`, { params });
  }

  getVistaMaterializada(anioMes?: string): Observable<AnaliticaMaterializada[]> {
    let params = new HttpParams();
    if (anioMes) params = params.set('anioMes', anioMes);
    return this.http.get<AnaliticaMaterializada[]>(`${this.baseUrl}/analitica/vista-materializada`, { params });
  }

  getDespivotadoMetricas(mes?: string): Observable<AnaliticaUnpivot[]> {
    let params = new HttpParams();
    if (mes) params = params.set('mes', mes);
    return this.http.get<AnaliticaUnpivot[]>(`${this.baseUrl}/analitica/despivotado-metricas`, { params });
  }

  getTopClientesClv(): Observable<AnaliticaClienteClv[]> {
    return this.http.get<AnaliticaClienteClv[]>(`${this.baseUrl}/analitica/top-clientes-clv`);
  }

  // ==========================================
  // Administración de Tablespace Histórico
  // ==========================================
  getTablespaceInfo(): Observable<TablespaceInfo> {
    return this.http.get<TablespaceInfo>(`${this.baseUrl}/tablespace/info`);
  }

  // ==========================================
  // Auditoría y Trazabilidad (Triggers)
  // ==========================================
  getAuditoriaResumen(): Observable<AuditoriaResumen> {
    return this.http.get<AuditoriaResumen>(`${this.baseUrl}/auditoria/resumen`);
  }

  getAuditoriaFilas(limite: number = 100): Observable<AuditoriaFila[]> {
    return this.http.get<AuditoriaFila[]>(`${this.baseUrl}/auditoria/filas`, {
      params: new HttpParams().set('limite', limite)
    });
  }

  getAuditoriaSentencias(limite: number = 100): Observable<AuditoriaSentencia[]> {
    return this.http.get<AuditoriaSentencia[]>(`${this.baseUrl}/auditoria/sentencias`, {
      params: new HttpParams().set('limite', limite)
    });
  }

  simularCambioTarifa(idHabitacion?: number, idTemporada?: number, porcentaje: number = 5.0): Observable<any> {
    let params = new HttpParams().set('porcentaje', porcentaje);
    if (idHabitacion) params = params.set('idHabitacion', idHabitacion);
    if (idTemporada) params = params.set('idTemporada', idTemporada);
    return this.http.post<any>(`${this.baseUrl}/auditoria/simular-cambio`, null, { params });
  }

  limpiarAuditoria(): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/auditoria/limpiar`);
  }

  getTarifasDetalle(idAlojamiento?: number, busqueda?: string): Observable<TarifaDetalle[]> {
    let params = new HttpParams();
    if (idAlojamiento) params = params.set('idAlojamiento', idAlojamiento);
    if (busqueda) params = params.set('busqueda', busqueda);
    return this.http.get<TarifaDetalle[]>(`${this.baseUrl}/auditoria/tarifas`, { params });
  }

  getPeriodosTemporada(): Observable<PeriodoTemporada[]> {
    return this.http.get<PeriodoTemporada[]>(`${this.baseUrl}/auditoria/periodos-temporada`);
  }

  guardarTarifa(req: GuardarTarifaRequest): Observable<{ mensaje: string; tarifa: TarifaDetalle }> {
    return this.http.post<{ mensaje: string; tarifa: TarifaDetalle }>(`${this.baseUrl}/auditoria/guardar-tarifa`, req);
  }
}
