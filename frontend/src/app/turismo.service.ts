import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface CatalogoItem {
  id: number;
  nombre: string;
  descripcion?: string;
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

@Injectable({
  providedIn: 'root'
})
export class TurismoService {
  private http = inject(HttpClient);
  private baseUrl = 'http://localhost:8080/api';

  // Catalogos
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

  // Entrega 2 - PL/SQL
  cotizar(idHabitacion: number, fechaIn: string, fechaOut: string): Observable<CotizacionResponse> {
    return this.http.post<CotizacionResponse>(`${this.baseUrl}/reservas/cotizar`, {
      id_habitacion: idHabitacion,
      fecha_in: fechaIn,
      fecha_out: fechaOut
    });
  }

  crearReserva(idCliente: number, idHabitacion: number, fechaIn: string, fechaOut: string, numHuespedes: number): Observable<ReservaResponse> {
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

  // Entrega 1 - Analitica
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
}
