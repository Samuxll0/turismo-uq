import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  TurismoService,
  CatalogoItem,
  HabitacionDetalle,
  CotizacionResponse,
  ReservaResponse,
  LiquidacionItem,
  AnaliticaOcupacion,
  AnaliticaJerarquia,
  AnaliticaTop,
  AnaliticaVariacion
} from './turismo.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './app.html',
  styleUrls: ['./app.css']
})
export class App implements OnInit {
  private api = inject(TurismoService);

  // Tab activo: 'cotizador' | 'reservas' | 'liquidacion' | 'analitica'
  tabActivo = signal<'cotizador' | 'reservas' | 'liquidacion' | 'analitica'>('cotizador');
  analiticaSubTab = signal<'pivot' | 'rollup' | 'rank' | 'lag'>('pivot');

  // Catalogos
  municipios = signal<CatalogoItem[]>([]);
  alojamientos = signal<CatalogoItem[]>([]);
  habitaciones = signal<HabitacionDetalle[]>([]);
  clientes = signal<CatalogoItem[]>([]);

  // Estados de carga y alertas
  cargando = signal<boolean>(false);
  mensajeExito = signal<string | null>(null);
  mensajeError = signal<string | null>(null);

  // Formulario Cotizador
  cotIdHabitacion: number | null = null;
  cotFechaIn: string = '2024-03-21';
  cotFechaOut: string = '2024-03-26';
  cotizacionResultado = signal<CotizacionResponse | null>(null);

  // Formulario Reservas
  resIdCliente: number | null = null;
  resIdHabitacion: number | null = null;
  resFechaIn: string = '2027-05-10';
  resFechaOut: string = '2027-05-15';
  resNumHuespedes: number = 2;
  reservaResultado = signal<ReservaResponse | null>(null);

  // Formulario Liquidacion
  liqMes: number = 7;
  liqAnio: number = 2025;
  liqIdAlojamiento: number | null = null;
  liquidaciones = signal<LiquidacionItem[]>([]);

  // Datos de Analitica
  datosPivot = signal<AnaliticaOcupacion[]>([]);
  datosRollup = signal<AnaliticaJerarquia[]>([]);
  datosRank = signal<AnaliticaTop[]>([]);
  datosLag = signal<AnaliticaVariacion[]>([]);

  ngOnInit() {
    this.cargarCatalogos();
  }

  cargarCatalogos() {
    this.api.getMunicipios().subscribe({
      next: data => this.municipios.set(data),
      error: err => console.error('Error cargando municipios', err)
    });

    this.api.getHabitaciones().subscribe({
      next: data => {
        this.habitaciones.set(data);
        if (data.length > 0) {
          this.cotIdHabitacion = data[0].id_habitacion;
          this.resIdHabitacion = data[0].id_habitacion;
        }
      },
      error: err => console.error('Error cargando habitaciones', err)
    });

    this.api.getClientes().subscribe({
      next: data => {
        this.clientes.set(data);
        if (data.length > 0) {
          this.resIdCliente = data[0].id;
        }
      },
      error: err => console.error('Error cargando clientes', err)
    });

    this.api.getAlojamientos().subscribe({
      next: data => this.alojamientos.set(data),
      error: err => console.error('Error cargando alojamientos', err)
    });
  }

  cambiarTab(tab: 'cotizador' | 'reservas' | 'liquidacion' | 'analitica') {
    this.tabActivo.set(tab);
    this.limpiarAlertas();
    if (tab === 'analitica' && this.datosPivot().length === 0) {
      this.cargarAnalitica();
    }
  }

  limpiarAlertas() {
    this.mensajeExito.set(null);
    this.mensajeError.set(null);
  }

  // Acciones de Cotizador
  ejecutarCotizacion() {
    if (!this.cotIdHabitacion || !this.cotFechaIn || !this.cotFechaOut) {
      this.mensajeError.set('Por favor completa todos los campos de cotización.');
      return;
    }
    this.cargando.set(true);
    this.limpiarAlertas();
    this.api.cotizar(this.cotIdHabitacion, this.cotFechaIn, this.cotFechaOut).subscribe({
      next: resp => {
        this.cargando.set(false);
        this.cotizacionResultado.set(resp);
        this.mensajeExito.set('Cotización calculada exitosamente por fn_valor_estadia en Oracle XE.');
      },
      error: err => {
        this.cargando.set(false);
        const msg = err.error?.message || 'Error al cotizar la estadía';
        this.mensajeError.set(msg);
      }
    });
  }

  setDemoCruzado() {
    this.cotFechaIn = '2024-03-21';
    this.cotFechaOut = '2024-03-26';
    if (this.habitaciones().length > 0) {
      this.cotIdHabitacion = this.habitaciones()[0].id_habitacion;
    }
    this.ejecutarCotizacion();
  }

  // Acciones de Reservas
  ejecutarCrearReserva() {
    if (!this.resIdCliente || !this.resIdHabitacion || !this.resFechaIn || !this.resFechaOut) {
      this.mensajeError.set('Por favor completa los datos de la reserva.');
      return;
    }
    this.cargando.set(true);
    this.limpiarAlertas();
    this.api.crearReserva(this.resIdCliente, this.resIdHabitacion, this.resFechaIn, this.resFechaOut, this.resNumHuespedes).subscribe({
      next: resp => {
        this.cargando.set(false);
        this.reservaResultado.set(resp);
        this.mensajeExito.set(`¡Reserva #${resp.id_reserva} creada exitosamente con estado ${resp.estado}! Total: $${resp.total.toLocaleString()}`);
      },
      error: err => {
        this.cargando.set(false);
        const code = err.error?.code || 'ERROR';
        const msg = err.error?.message || 'Error en el registro';
        this.mensajeError.set(`[Excepción ${code}] ${msg}`);
      }
    });
  }

  probarCasoExitoso() {
    this.resFechaIn = '2027-08-10';
    this.resFechaOut = '2027-08-15';
    this.resNumHuespedes = 2;
    this.ejecutarCrearReserva();
  }

  probarErrorFechas() {
    this.resFechaIn = '2027-08-20';
    this.resFechaOut = '2027-08-15'; // Menor que check-in
    this.resNumHuespedes = 2;
    this.ejecutarCrearReserva();
  }

  probarErrorCapacidad() {
    this.resFechaIn = '2027-09-01';
    this.resFechaOut = '2027-09-05';
    this.resNumHuespedes = 99; // Capacidad excedida
    this.ejecutarCrearReserva();
  }

  probarErrorSolapamiento() {
    // Si ya existe una reserva en 2027-08-10 a 2027-08-15, intentamos reservar en medio
    this.resFechaIn = '2027-08-12';
    this.resFechaOut = '2027-08-14';
    this.resNumHuespedes = 1;
    this.ejecutarCrearReserva();
  }

  // Acciones de Liquidacion
  ejecutarLiquidacion() {
    this.cargando.set(true);
    this.limpiarAlertas();
    this.api.getLiquidaciones(this.liqMes, this.liqAnio, this.liqIdAlojamiento || undefined).subscribe({
      next: data => {
        this.cargando.set(false);
        this.liquidaciones.set(data);
        this.mensajeExito.set(`Proceso por lotes finalizado: ${data.length} alojamientos liquidados y persistidos en Oracle XE.`);
      },
      error: err => {
        this.cargando.set(false);
        this.mensajeError.set(err.error?.message || 'Error al ejecutar liquidación masiva');
      }
    });
  }

  // Acciones de Analitica
  cargarAnalitica() {
    this.cargando.set(true);
    this.api.getOcupacionMensual().subscribe(d => this.datosPivot.set(d));
    this.api.getIngresosJerarquia().subscribe(d => this.datosRollup.set(d));
    this.api.getTopAlojamientos().subscribe(d => this.datosRank.set(d));
    this.api.getVariacionMes().subscribe(d => {
      this.datosLag.set(d);
      this.cargando.set(false);
    });
  }

  getHabitacionSeleccionada(): HabitacionDetalle | undefined {
    return this.habitaciones().find(h => h.id_habitacion === Number(this.cotIdHabitacion));
  }
}
