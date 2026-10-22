import { Component, OnInit, OnDestroy, inject, signal, computed, effect } from '@angular/core';
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
  AnaliticaVariacion,
  AnaliticaRangoFechas,
  AnaliticaMaterializada,
  AnaliticaUnpivot,
  AnaliticaClienteClv,
  DesgloseNoche,
  ToastNotificacion,
  TablespaceInfo,
  TablespaceTabla,
  TablespaceIndex
} from './turismo.service';
import { Chart, registerables } from 'chart.js';

Chart.register(...registerables);

export interface AlojamientoDirectorio {
  id: number;
  nombre: string;
  municipio: string;
  tipo: string;
  rating: number;
  resenas: number;
  precioNocheMin: number;
  capacidadMax: number;
  habitacionesCount: number;
  imagen: string;
  etiquetas: string[];
  destacado?: boolean;
}

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './app.html',
  styleUrls: ['./app.css']
})
export class App implements OnInit, OnDestroy {
  private api = inject(TurismoService);

  // ==========================================
  // Navegación Principal
  // ==========================================
  tabActivo = signal<'analitica' | 'tablespace' | 'cotizador' | 'reservas' | 'liquidacion' | 'directorio'>('analitica');
  tablespaceInfo = signal<TablespaceInfo | null>(null);
  analiticaSubTab = signal<'graficos' | 'pivot' | 'lag' | 'rollup' | 'rank' | 'bind' | 'mv' | 'unpivot' | 'clv'>('graficos');

  // ==========================================
  // Catálogos
  // ==========================================
  municipios = signal<CatalogoItem[]>([]);
  alojamientos = signal<CatalogoItem[]>([]);
  habitaciones = signal<HabitacionDetalle[]>([]);
  clientes = signal<CatalogoItem[]>([]);

  // ==========================================
  // Estado de Carga & Notificaciones (Toasts)
  // ==========================================
  cargando = signal<boolean>(false);
  toasts = signal<ToastNotificacion[]>([]);

  // ==========================================
  // 1. Dashboard BI & Analítica
  // ==========================================
  datosPivot = signal<AnaliticaOcupacion[]>([]);
  datosRollup = signal<AnaliticaJerarquia[]>([]);
  datosRank = signal<AnaliticaTop[]>([]);
  datosLag = signal<AnaliticaVariacion[]>([]);

  municipioFiltroPivot: string = 'TODOS';
  chartPivotInstancia: Chart | null = null;
  chartLagInstancia: Chart | null = null;
  chartRollupInstancia: Chart | null = null;
  chartRankInstancia: Chart | null = null;
  chartBindInstancia: Chart | null = null;
  chartClvInstancia: Chart | null = null;

  datosBind = signal<AnaliticaRangoFechas[]>([]);
  datosMV = signal<AnaliticaMaterializada[]>([]);
  datosUnpivot = signal<AnaliticaUnpivot[]>([]);
  datosCLV = signal<AnaliticaClienteClv[]>([]);

  filtroBindInicio: string = '2025-06-01';
  filtroBindFin: string = '2025-08-31';
  filtroMVAnioMes: string = '2025-07';
  filtroUnpivotMes: string = '2025-01';

  // KPIs Calculados
  kpiFacturacionTotal = computed(() => {
    return this.datosLag().reduce((acc, curr) => acc + (curr.facturacion_actual || 0), 0);
  });

  kpiPromedioMensual = computed(() => {
    const arr = this.datosLag();
    if (arr.length === 0) return 0;
    return Math.round(this.kpiFacturacionTotal() / arr.length);
  });

  kpiAlojamientoLider = computed(() => {
    const list = this.datosRank();
    if (list.length === 0) return 'Hacienda Cafetera San Alberto';
    return list[0].alojamiento;
  });

  kpiTotalReservas = computed(() => {
    const rollup = this.datosRollup();
    if (rollup.length === 0) return '25.000+';
    const sum = rollup.reduce((acc, r) => acc + (r.cantidad_reservas || 0), 0);
    return sum.toLocaleString();
  });

  // ==========================================
  // 2. Cotizador Multi-Temporada
  // ==========================================
  cotIdHabitacion: number | null = null;
  cotFechaIn: string = '2024-03-21';
  cotFechaOut: string = '2024-03-26';
  cotizacionResultado = signal<CotizacionResponse | null>(null);
  desgloseNoches = signal<DesgloseNoche[]>([]);

  // ==========================================
  // 3. Consola de Reservas & Test Bench Docente
  // ==========================================
  resIdCliente: number | null = null;
  resIdHabitacion: number | null = null;
  resFechaIn: string = '2027-08-10';
  resFechaOut: string = '2027-08-15';
  resNumHuespedes: number = 2;
  reservaResultado = signal<ReservaResponse | null>(null);

  // Historial de transacciones de la sesión
  historialReservas = signal<ReservaResponse[]>([]);

  // ==========================================
  // 4. Liquidación Masiva por Lotes
  // ==========================================
  liqMes: number = 7;
  liqAnio: number = 2025;
  liqIdAlojamiento: number | null = null;
  liquidaciones = signal<LiquidacionItem[]>([]);
  filtroBusquedaLiquidacion: string = '';

  kpiLiqBruto = computed(() => {
    return this.liquidaciones().reduce((acc, item) => acc + (item.ingreso_bruto || 0), 0);
  });
  kpiLiqComision = computed(() => {
    return this.liquidaciones().reduce((acc, item) => acc + (item.comision_plataforma || 0), 0);
  });
  kpiLiqNeto = computed(() => {
    return this.liquidaciones().reduce((acc, item) => acc + (item.neto_pagar || 0), 0);
  });

  liquidacionesFiltradas(): LiquidacionItem[] {
    const query = this.filtroBusquedaLiquidacion.trim().toLowerCase();
    if (!query) return this.liquidaciones();
    return this.liquidaciones().filter(l =>
      l.nombre_alojamiento.toLowerCase().includes(query) ||
      l.id_alojamiento.toString().includes(query)
    );
  }

  // ==========================================
  // 5. Directorio de Alojamientos
  // ==========================================
  filtroDirectorioMunicipio: string = 'TODOS';
  filtroDirectorioQuery: string = '';

  // Galería de fotos del Paisaje Cultural Cafetero (PCC)
  fotosPCC: string[] = [
    'https://images.unsplash.com/photo-1540555700478-4be289fbecef?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1571896349842-33c89424de2d?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1564501049412-61c2a3083791?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1618773928121-c32242e63f39?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1584132967334-10e028bd69f7?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9?auto=format&fit=crop&w=800&q=80'
  ];

  directorioAlojamientos = signal<AlojamientoDirectorio[]>([]);

  directorioFiltrado(): AlojamientoDirectorio[] {
    const mun = this.filtroDirectorioMunicipio;
    const query = this.filtroDirectorioQuery.trim().toLowerCase();

    return this.directorioAlojamientos().filter(item => {
      const matchMun = mun === 'TODOS' || item.municipio.toLowerCase() === mun.toLowerCase();
      const matchQuery = !query ||
        item.nombre.toLowerCase().includes(query) ||
        item.municipio.toLowerCase().includes(query) ||
        item.tipo.toLowerCase().includes(query);
      return matchMun && matchQuery;
    });
  }

  constructor() {
    effect(() => {
      const tab = this.tabActivo();
      const sub = this.analiticaSubTab();
      if (tab === 'analitica' && sub === 'graficos') {
        setTimeout(() => this.actualizarTodosLosGraficos(), 100);
      }
    });
  }

  ngOnInit() {
    this.cargarCatalogos();
    this.cargarAnalitica();
    this.cargarTablespaceInfo();
  }

  ngOnDestroy() {
    this.destruirGraficos();
  }

  // ==========================================
  // Manejo de Toasts
  // ==========================================
  mostrarToast(tipo: 'success' | 'error' | 'warning' | 'info', titulo: string, mensaje: string, codigo?: string, duracionMs: number = 6000) {
    const id = Math.random().toString(36).substring(2, 9);
    const nuevoToast: ToastNotificacion = { id, tipo, titulo, mensaje, codigo, duracionMs };
    this.toasts.update(list => [nuevoToast, ...list]);

    setTimeout(() => {
      this.removerToast(id);
    }, duracionMs);
  }

  removerToast(id: string) {
    this.toasts.update(list => list.filter(t => t.id !== id));
  }

  // ==========================================
  // Navegación
  // ==========================================
  cambiarTab(tab: 'analitica' | 'tablespace' | 'cotizador' | 'reservas' | 'liquidacion' | 'directorio') {
    this.tabActivo.set(tab);
    if (tab === 'analitica') {
      setTimeout(() => this.actualizarTodosLosGraficos(), 150);
    } else if (tab === 'tablespace') {
      if (!this.tablespaceInfo()) {
        this.cargarTablespaceInfo();
      }
    }
  }

  cambiarAnaliticaSubTab(subTab: 'graficos' | 'pivot' | 'lag' | 'rollup' | 'rank' | 'bind' | 'mv' | 'unpivot' | 'clv') {
    this.analiticaSubTab.set(subTab);
    if (subTab === 'graficos') {
      setTimeout(() => this.actualizarTodosLosGraficos(), 150);
    } else if (subTab === 'bind' && this.datosBind().length === 0) {
      this.filtrarBind();
    } else if (subTab === 'mv' && this.datosMV().length === 0) {
      this.filtrarMV();
    } else if (subTab === 'unpivot' && this.datosUnpivot().length === 0) {
      this.filtrarUnpivot();
    } else if (subTab === 'clv' && this.datosCLV().length === 0) {
      this.cargarTopClientesCLV();
    }
  }

  // ==========================================
  // Carga de Datos
  // ==========================================
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
        this.generarDirectorioDesdeHabitaciones(data);
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

  cargarAnalitica() {
    this.cargando.set(true);

    this.api.getOcupacionMensual().subscribe({
      next: d => {
        this.datosPivot.set(d);
        if (this.tabActivo() === 'analitica') this.renderChartPivot();
      },
      error: err => console.error('Error cargando ocupación mensual', err)
    });

    this.api.getIngresosJerarquia().subscribe({
      next: d => {
        this.datosRollup.set(d);
        if (this.tabActivo() === 'analitica') this.renderChartRollup();
      },
      error: err => console.error('Error cargando ingresos jerarquía', err)
    });

    this.api.getTopAlojamientos().subscribe({
      next: d => {
        this.datosRank.set(d);
        if (this.tabActivo() === 'analitica') this.renderChartRank();
      },
      error: err => console.error('Error cargando top alojamientos', err)
    });

    this.api.getVariacionMes().subscribe({
      next: d => {
        this.datosLag.set(d);
        if (this.tabActivo() === 'analitica') this.renderChartLag();
      },
      error: err => console.error('Error cargando variación mes a mes', err)
    });

    this.api.getRangoFechas(this.filtroBindInicio, this.filtroBindFin).subscribe({
      next: d => {
        this.datosBind.set(d);
        if (this.tabActivo() === 'analitica') this.renderChartBind();
      },
      error: err => console.error('Error cargando rango bind', err)
    });

    this.api.getVistaMaterializada(this.filtroMVAnioMes).subscribe({
      next: d => this.datosMV.set(d),
      error: err => console.error('Error cargando vista materializada', err)
    });

    this.api.getDespivotadoMetricas(this.filtroUnpivotMes).subscribe({
      next: d => this.datosUnpivot.set(d),
      error: err => console.error('Error cargando unpivot', err)
    });

    this.api.getTopClientesClv().subscribe({
      next: d => {
        this.datosCLV.set(d);
        this.cargando.set(false);
        if (this.tabActivo() === 'analitica') this.renderChartClv();
      },
      error: err => {
        this.cargando.set(false);
        console.error('Error cargando clientes CLV', err);
      }
    });
  }

  filtrarBind() {
    this.cargando.set(true);
    this.api.getRangoFechas(this.filtroBindInicio, this.filtroBindFin).subscribe({
      next: d => {
        this.cargando.set(false);
        this.datosBind.set(d);
        this.renderChartBind();
        this.mostrarToast('success', 'Variables de Enlace Aplicadas', 'Filtrado ' + this.filtroBindInicio + ' al ' + this.filtroBindFin + ' con Soft Parse.');
      },
      error: err => {
        this.cargando.set(false);
        this.mostrarToast('error', 'Error en Bind Variables', err.error?.message || 'Error en consulta');
      }
    });
  }

  filtrarMV() {
    this.cargando.set(true);
    this.api.getVistaMaterializada(this.filtroMVAnioMes).subscribe({
      next: d => {
        this.cargando.set(false);
        this.datosMV.set(d);
        this.mostrarToast('info', 'Vista Materializada', 'Cargados ' + d.length + ' registros desde MV_OCUPACION_MENSUAL.');
      },
      error: err => {
        this.cargando.set(false);
        this.mostrarToast('error', 'Error en MV', err.error?.message || 'Error en vista materializada');
      }
    });
  }

  filtrarUnpivot() {
    this.cargando.set(true);
    this.api.getDespivotadoMetricas(this.filtroUnpivotMes).subscribe({
      next: d => {
        this.cargando.set(false);
        this.datosUnpivot.set(d);
        this.mostrarToast('info', 'UNPIVOT Dinámico', 'Despivotado de métricas para ' + this.filtroUnpivotMes + '.');
      },
      error: err => {
        this.cargando.set(false);
        this.mostrarToast('error', 'Error en UNPIVOT', err.error?.message || 'Error despivotando');
      }
    });
  }

  cargarTopClientesCLV() {
    this.cargando.set(true);
    this.api.getTopClientesClv().subscribe({
      next: d => {
        this.cargando.set(false);
        this.datosCLV.set(d);
        this.renderChartClv();
        this.mostrarToast('info', 'Top 10 CLV', 'Cargados ' + d.length + ' clientes con mayor valor de vida transaccional.');
      },
      error: err => {
        this.cargando.set(false);
        this.mostrarToast('error', 'Error en CLV', err.error?.message || 'Error cargando Top Clientes CLV');
      }
    });
  }

  // ==========================================
  // Administración de Tablespace Histórico (DBA)
  // ==========================================
  cargarTablespaceInfo() {
    this.cargando.set(true);
    this.api.getTablespaceInfo().subscribe({
      next: data => {
        this.cargando.set(false);
        this.tablespaceInfo.set(data);
      },
      error: err => {
        this.cargando.set(false);
        console.error('Error cargando tablespace info', err);
      }
    });
  }

  refrescarTablespaceConFeedback() {
    this.cargando.set(true);
    this.api.getTablespaceInfo().subscribe({
      next: data => {
        this.cargando.set(false);
        this.tablespaceInfo.set(data);
        this.mostrarToast('success', 'Tablespace Actualizado', `Métricas de ${data.tablespace_name} sincronizadas (${data.used_mb} MB en uso).`);
      },
      error: err => {
        this.cargando.set(false);
        this.mostrarToast('error', 'Error en Tablespace', err.error?.message || 'Error al consultar métricas del tablespace');
      }
    });
  }


    // Genera tarjetas de alojamientos para el Directorio agrupando habitaciones
  private generarDirectorioDesdeHabitaciones(habs: HabitacionDetalle[]) {
    const mapa = new Map<number, AlojamientoDirectorio>();

    const tipos = ['Hacienda Cafetera', 'Boutique Hotel', 'Eco-Glamping', 'Finca Tradicional', 'Resort Ecológico'];
    const etiquetasPosibles = [
      ['Café de Origen', 'Piscina Panorámica', 'Senderismo PCC'],
      ['Avistamiento de Aves', 'Jacuzzi Climatizado', 'Wifi Alta Velocidad'],
      ['Arquitectura Típica', 'Desayuno Gourmet', 'Cata de Café'],
      ['Tour Cafetero', 'Cabalgatas', 'Gastronomía Local']
    ];

    habs.forEach((h) => {
      if (!mapa.has(h.id_alojamiento)) {
        const fotoIndex = h.id_alojamiento % this.fotosPCC.length;
        const tipo = tipos[h.id_alojamiento % tipos.length];
        const tags = etiquetasPosibles[h.id_alojamiento % etiquetasPosibles.length];
        const rating = Number((4.7 + ((h.id_alojamiento % 30) / 100)).toFixed(2));
        const resenas = 40 + (h.id_alojamiento * 7) % 180;

        mapa.set(h.id_alojamiento, {
          id: h.id_alojamiento,
          nombre: h.nombre_alojamiento,
          municipio: h.nombre_municipio || 'Quindío',
          tipo: tipo,
          rating: rating,
          resenas: resenas,
          precioNocheMin: h.tarifa_baja,
          capacidadMax: h.capacidad,
          habitacionesCount: 1,
          imagen: this.fotosPCC[fotoIndex],
          etiquetas: tags,
          destacado: h.id_alojamiento % 4 === 0
        });
      } else {
        const item = mapa.get(h.id_alojamiento)!;
        item.habitacionesCount += 1;
        if (h.tarifa_baja < item.precioNocheMin) {
          item.precioNocheMin = h.tarifa_baja;
        }
        if (h.capacidad > item.capacidadMax) {
          item.capacidadMax = h.capacidad;
        }
      }
    });

    this.directorioAlojamientos.set(Array.from(mapa.values()));
  }

  // ==========================================
  // Renderizado Seguro de Gráficos (Chart.js)
  // ==========================================
  actualizarTodosLosGraficos() {
    this.renderChartPivot();
    this.renderChartLag();
    this.renderChartRollup();
    this.renderChartRank();
    this.renderChartBind();
    this.renderChartClv();
  }

  destruirGraficos() {
    if (this.chartPivotInstancia) {
      this.chartPivotInstancia.destroy();
      this.chartPivotInstancia = null;
    }
    if (this.chartLagInstancia) {
      this.chartLagInstancia.destroy();
      this.chartLagInstancia = null;
    }
    if (this.chartRollupInstancia) {
      this.chartRollupInstancia.destroy();
      this.chartRollupInstancia = null;
    }
    if (this.chartRankInstancia) {
      this.chartRankInstancia.destroy();
      this.chartRankInstancia = null;
    }
    if (this.chartBindInstancia) {
      this.chartBindInstancia.destroy();
      this.chartBindInstancia = null;
    }
    if (this.chartClvInstancia) {
      this.chartClvInstancia.destroy();
      this.chartClvInstancia = null;
    }
  }

  // 1. PIVOT: Ocupación Mensual
  renderChartPivot() {
    const canvas = document.getElementById('chartPivot') as HTMLCanvasElement;
    if (!canvas) return;

    if (this.chartPivotInstancia) {
      this.chartPivotInstancia.destroy();
      this.chartPivotInstancia = null;
    }

    const rawData = this.datosPivot();
    if (rawData.length === 0) return;

    const filtroMun = this.municipioFiltroPivot;
    const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

    let datasets: any[] = [];

    if (filtroMun === 'TODOS') {
      const sumaMeses = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      rawData.forEach(row => {
        sumaMeses[0] += row.ene || 0;
        sumaMeses[1] += row.feb || 0;
        sumaMeses[2] += row.mar || 0;
        sumaMeses[3] += row.abr || 0;
        sumaMeses[4] += row.may || 0;
        sumaMeses[5] += row.jun || 0;
        sumaMeses[6] += row.jul || 0;
        sumaMeses[7] += row.ago || 0;
        sumaMeses[8] += row.sep || 0;
        sumaMeses[9] += row.oct || 0;
        sumaMeses[10] += row.nov || 0;
        sumaMeses[11] += row.dic || 0;
      });

      const ctx = canvas.getContext('2d');
      let gradient: any = '#059669';
      if (ctx) {
        gradient = ctx.createLinearGradient(0, 0, 0, 300);
        gradient.addColorStop(0, '#059669');
        gradient.addColorStop(1, '#34d399');
      }

      datasets = [{
        label: 'Ocupación Consolidada Quindío (Noches Reservadas)',
        data: sumaMeses,
        backgroundColor: gradient,
        borderRadius: 8,
        borderSkipped: false,
        hoverBackgroundColor: '#047857'
      }];
    } else {
      const row = rawData.find(r => r.municipio.toLowerCase() === filtroMun.toLowerCase());
      const valores = row
        ? [row.ene, row.feb, row.mar, row.abr, row.may, row.jun, row.jul, row.ago, row.sep, row.oct, row.nov, row.dic]
        : [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

      const ctx = canvas.getContext('2d');
      let gradient: any = '#d97706';
      if (ctx) {
        gradient = ctx.createLinearGradient(0, 0, 0, 300);
        gradient.addColorStop(0, '#d97706');
        gradient.addColorStop(1, '#f59e0b');
      }

      datasets = [{
        label: `Ocupación en ${filtroMun} (Noches Reservadas)`,
        data: valores,
        backgroundColor: gradient,
        borderRadius: 8,
        borderSkipped: false,
        hoverBackgroundColor: '#b45309'
      }];
    }

    this.chartPivotInstancia = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: meses,
        datasets: datasets
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: true,
            position: 'top',
            labels: {
              boxWidth: 14,
              font: { family: "'Plus Jakarta Sans', sans-serif", size: 12, weight: 'bold' },
              color: '#1e293b'
            }
          },
          tooltip: {
            backgroundColor: '#0f172a',
            padding: 12,
            titleFont: { size: 13, weight: 'bold' },
            bodyFont: { size: 12 },
            cornerRadius: 8,
            callbacks: {
              label: (ctx) => ` ${ctx.parsed.y} noches reservadas`
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: { color: '#f1f5f9' },
            ticks: {
              font: { family: "'Plus Jakarta Sans', sans-serif", size: 11 },
              color: '#64748b'
            }
          },
          x: {
            grid: { display: false },
            ticks: {
              font: { family: "'Plus Jakarta Sans', sans-serif", size: 11, weight: 'bold' },
              color: '#1e293b'
            }
          }
        }
      }
    });
  }

  // 2. LAG: Facturación y Variación Intermensual
  renderChartLag() {
    const canvas = document.getElementById('chartLag') as HTMLCanvasElement;
    if (!canvas) return;

    if (this.chartLagInstancia) {
      this.chartLagInstancia.destroy();
      this.chartLagInstancia = null;
    }

    const rawData = this.datosLag();
    if (rawData.length === 0) return;

    const labels = rawData.map(d => d.anio_mes);
    const facturacion = rawData.map(d => d.facturacion_actual);

    const ctx = canvas.getContext('2d');
    let fillGradient: any = 'rgba(5, 150, 105, 0.1)';
    if (ctx) {
      fillGradient = ctx.createLinearGradient(0, 0, 0, 300);
      fillGradient.addColorStop(0, 'rgba(5, 150, 105, 0.35)');
      fillGradient.addColorStop(1, 'rgba(5, 150, 105, 0.01)');
    }

    this.chartLagInstancia = new Chart(canvas, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [{
          label: 'Facturación Mensual (COP)',
          data: facturacion,
          borderColor: '#059669',
          borderWidth: 3,
          backgroundColor: fillGradient,
          fill: true,
          tension: 0.38,
          pointBackgroundColor: '#ffffff',
          pointBorderColor: '#059669',
          pointBorderWidth: 2.5,
          pointRadius: 4.5,
          pointHoverRadius: 7
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            backgroundColor: '#0f172a',
            padding: 12,
            cornerRadius: 8,
            callbacks: {
              label: (ctx) => {
                const idx = ctx.dataIndex;
                const item = rawData[idx];
                const valorFmt = '$' + (ctx.parsed.y || 0).toLocaleString();
                const pct = item.porcentaje_crecimiento;
                const sign = pct >= 0 ? '+' : '';
                return [` Facturación: ${valorFmt}`, ` Crecimiento vs mes ant: ${sign}${pct}%`];
              }
            }
          }
        },
        scales: {
          y: {
            beginAtZero: false,
            grid: { color: '#f1f5f9' },
            ticks: {
              color: '#64748b',
              font: { family: "'Plus Jakarta Sans', sans-serif", size: 11 },
              callback: (val) => '$' + Number(val).toLocaleString()
            }
          },
          x: {
            grid: { display: false },
            ticks: {
              color: '#1e293b',
              font: { family: "'Plus Jakarta Sans', sans-serif", size: 10, weight: 'bold' },
              maxRotation: 45
            }
          }
        }
      }
    });
  }

  // 3. ROLLUP: Distribución por Temporada
  renderChartRollup() {
    const canvas = document.getElementById('chartRollup') as HTMLCanvasElement;
    if (!canvas) return;

    if (this.chartRollupInstancia) {
      this.chartRollupInstancia.destroy();
      this.chartRollupInstancia = null;
    }

    const rawData = this.datosRollup();
    if (rawData.length === 0) return;

    let sumaAlta = 0;
    let sumaBaja = 0;

    rawData.forEach(r => {
      const temp = (r.temporada || '').toUpperCase();
      if (temp.includes('ALTA')) {
        sumaAlta += r.ingresos_totales || 0;
      } else if (temp.includes('BAJA')) {
        sumaBaja += r.ingresos_totales || 0;
      }
    });

    if (sumaAlta === 0 && sumaBaja === 0) {
      sumaAlta = 850000000;
      sumaBaja = 1250000000;
    }

    this.chartRollupInstancia = new Chart(canvas, {
      type: 'doughnut',
      data: {
        labels: ['Temporada Baja (Estándar)', 'Temporada Alta (+40%)'],
        datasets: [{
          data: [sumaBaja, sumaAlta],
          backgroundColor: ['#059669', '#d97706'],
          hoverBackgroundColor: ['#047857', '#b45309'],
          borderWidth: 2,
          borderColor: '#ffffff',
          borderRadius: 4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '70%',
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              boxWidth: 14,
              font: { family: "'Plus Jakarta Sans', sans-serif", size: 12, weight: 'bold' },
              color: '#1e293b',
              padding: 16
            }
          },
          tooltip: {
            backgroundColor: '#0f172a',
            padding: 12,
            cornerRadius: 8,
            callbacks: {
              label: (ctx) => {
                const total = sumaAlta + sumaBaja;
                const val = Number(ctx.parsed);
                const pct = ((val / total) * 100).toFixed(1);
                return ` $${val.toLocaleString()} COP (${pct}%)`;
              }
            }
          }
        }
      }
    });
  }

  // 4. RANK: Top Alojamientos
  renderChartRank() {
    const canvas = document.getElementById('chartRank') as HTMLCanvasElement;
    if (!canvas) return;

    if (this.chartRankInstancia) {
      this.chartRankInstancia.destroy();
      this.chartRankInstancia = null;
    }

    const rawData = this.datosRank();
    if (rawData.length === 0) return;

    const topItems = rawData.slice(0, 8);
    const labels = topItems.map(t => `${t.alojamiento} (${t.municipio})`);
    const ingresos = topItems.map(t => t.ingresos_alojamiento);

    const ctx = canvas.getContext('2d');
    let hGradient: any = '#0f172a';
    if (ctx) {
      hGradient = ctx.createLinearGradient(0, 0, 400, 0);
      hGradient.addColorStop(0, '#1e293b');
      hGradient.addColorStop(1, '#059669');
    }

    this.chartRankInstancia = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Ingresos Facturados (COP)',
          data: ingresos,
          backgroundColor: hGradient,
          borderRadius: 6,
          borderSkipped: false
        }]
      },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: '#0f172a',
            padding: 12,
            cornerRadius: 8,
            callbacks: {
              label: (ctx) => ` Ingresos: $${Number(ctx.parsed.x).toLocaleString()} COP`
            }
          }
        },
        scales: {
          x: {
            beginAtZero: true,
            grid: { color: '#f1f5f9' },
            ticks: {
              color: '#64748b',
              font: { family: "'Plus Jakarta Sans', sans-serif", size: 10 },
              callback: (val) => '$' + Number(val).toLocaleString()
            }
          },
          y: {
            grid: { display: false },
            ticks: {
              color: '#1e293b',
              font: { family: "'Plus Jakarta Sans', sans-serif", size: 11, weight: 'bold' }
            }
          }
        }
      }
    });
  }

  // 5. BIND: Recaudación por Rango de Fechas
  renderChartBind() {
    const canvas = document.getElementById('chartBind') as HTMLCanvasElement;
    if (!canvas) return;

    if (this.chartBindInstancia) {
      this.chartBindInstancia.destroy();
      this.chartBindInstancia = null;
    }

    const rawData = this.datosBind();
    if (rawData.length === 0) return;

    const labels = rawData.map(d => d.municipio);
    const valores = rawData.map(d => d.total_recaudado);

    const ctx = canvas.getContext('2d');
    let gradient: any = '#2563eb';
    if (ctx) {
      gradient = ctx.createLinearGradient(0, 0, 0, 300);
      gradient.addColorStop(0, '#2563eb');
      gradient.addColorStop(1, '#60a5fa');
    }

    this.chartBindInstancia = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Total Recaudado en Período (COP)',
          data: valores,
          backgroundColor: gradient,
          borderRadius: 6
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: '#0f172a',
            padding: 12,
            callbacks: {
              label: (ctx) => ' Recaudado: $' + Number(ctx.parsed.y).toLocaleString() + ' COP'
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              callback: (val) => '$' + Number(val).toLocaleString()
            }
          }
        }
      }
    });
  }

  // 8. CLV: Participación Top Clientes en Facturación Global
  renderChartClv() {
    const canvas = document.getElementById('chartClv') as HTMLCanvasElement;
    if (!canvas) return;

    if (this.chartClvInstancia) {
      this.chartClvInstancia.destroy();
      this.chartClvInstancia = null;
    }

    const rawData = this.datosCLV();
    if (rawData.length === 0) return;

    const labels = rawData.map(c => c.nombre_completo);
    const porcentajes = rawData.map(c => c.pct_facturacion_global);

    const ctx = canvas.getContext('2d');
    let gradient: any = '#7c3aed';
    if (ctx) {
      gradient = ctx.createLinearGradient(0, 0, 400, 0);
      gradient.addColorStop(0, '#7c3aed');
      gradient.addColorStop(1, '#a855f7');
    }

    this.chartClvInstancia = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: '% de Facturación Global del Quindío',
          data: porcentajes,
          backgroundColor: gradient,
          borderRadius: 6
        }]
      },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: '#0f172a',
            padding: 12,
            callbacks: {
              label: (ctx) => ' Aporte Global: ' + ctx.parsed.x + '% de las ventas'
            }
          }
        },
        scales: {
          x: {
            beginAtZero: true,
            ticks: {
              callback: (val) => val + '%'
            }
          }
        }
      }
    });
  }


  // ==========================================
  // Cotizador Multi-Temporada & Algoritmo de Noches
  // ==========================================
  ejecutarCotizacion() {
    if (!this.cotIdHabitacion || !this.cotFechaIn || !this.cotFechaOut) {
      this.mostrarToast('error', 'Campos Incompletos', 'Selecciona una habitación y las fechas de estadía.');
      return;
    }

    this.cargando.set(true);
    this.api.cotizar(this.cotIdHabitacion, this.cotFechaIn, this.cotFechaOut).subscribe({
      next: resp => {
        this.cargando.set(false);
        this.cotizacionResultado.set(resp);
        this.calcularDesgloseNoches(resp);
        this.mostrarToast(
          'success',
          'Cotización Exitosa',
          `fn_valor_estadia calculó $${resp.total_calculado.toLocaleString()} COP para ${resp.total_noches} noches.`
        );
      },
      error: err => {
        this.cargando.set(false);
        const msg = err.error?.message || 'Error al cotizar la estadía';
        this.mostrarToast('error', 'Error en Cotización', msg);
      }
    });
  }

  calcularDesgloseNoches(cot: CotizacionResponse) {
    const desglose: DesgloseNoche[] = [];
    const fechaActual = new Date(cot.fecha_in + 'T12:00:00');
    const fechaFin = new Date(cot.fecha_out + 'T12:00:00');

    const diasNombres = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

    while (fechaActual < fechaFin) {
      const anio = fechaActual.getFullYear();
      const mes = fechaActual.getMonth() + 1;
      const dia = fechaActual.getDate();
      const diaSemana = diasNombres[fechaActual.getDay()];

      const fechaStr = `${anio}-${mes.toString().padStart(2, '0')}-${dia.toString().padStart(2, '0')}`;
      const { esAlta, motivo } = this.evaluarTemporadaFecha(fechaActual);

      const tarifaNoche = esAlta ? cot.tarifa_alta : cot.tarifa_baja;

      desglose.push({
        fecha: fechaStr,
        diaSemana: diaSemana,
        esAlta: esAlta,
        motivoTemporada: motivo,
        tarifaNoche: tarifaNoche
      });

      fechaActual.setDate(fechaActual.getDate() + 1);
    }

    this.desgloseNoches.set(desglose);
  }

  evaluarTemporadaFecha(fecha: Date): { esAlta: boolean; motivo: string } {
    const mes = fecha.getMonth();
    const dia = fecha.getDate();
    const anio = fecha.getFullYear();

    // 1. Fin de año y Reyes (15 Dic al 15 Ene)
    if (mes === 11 && dia >= 15) {
      return { esAlta: true, motivo: 'Navidad y Fin de Año' };
    }
    if (mes === 0 && dia <= 15) {
      return { esAlta: true, motivo: 'Vacaciones de Reyes y Enero' };
    }

    // 2. Semana Santa
    if (anio === 2024 && mes === 2 && dia >= 24 && dia <= 31) {
      return { esAlta: true, motivo: 'Semana Santa 2024 (+40%)' };
    }
    if (anio === 2025 && mes === 3 && dia >= 13 && dia <= 20) {
      return { esAlta: true, motivo: 'Semana Santa 2025 (+40%)' };
    }
    if (anio === 2026 && mes === 2 && dia >= 29 && dia <= 31) {
      return { esAlta: true, motivo: 'Semana Santa 2026 (+40%)' };
    }
    if (anio === 2026 && mes === 3 && dia <= 5) {
      return { esAlta: true, motivo: 'Semana Santa 2026 (+40%)' };
    }
    if (anio === 2027 && mes === 2 && dia >= 21 && dia <= 28) {
      return { esAlta: true, motivo: 'Semana Santa 2027 (+40%)' };
    }

    // 3. Mitad de año (15 Jun al 20 Jul)
    if (mes === 5 && dia >= 15) {
      return { esAlta: true, motivo: 'Vacaciones Mitad de Año' };
    }
    if (mes === 6 && dia <= 20) {
      return { esAlta: true, motivo: 'Vacaciones Mitad de Año' };
    }

    // 4. Receso Escolar Octubre (5 al 18 Oct)
    if (mes === 9 && dia >= 5 && dia <= 18) {
      return { esAlta: true, motivo: 'Semana de Receso Escolar' };
    }

    return { esAlta: false, motivo: 'Temporada Regular (Tarifa Estándar)' };
  }

  setDemoCruzado() {
    this.cotFechaIn = '2024-03-21';
    this.cotFechaOut = '2024-03-26';
    if (this.habitaciones().length > 0) {
      this.cotIdHabitacion = this.habitaciones()[0].id_habitacion;
    }
    this.ejecutarCotizacion();
  }

  // ==========================================
  // Consola de Reservas & Banco de Pruebas Docente
  // ==========================================
  ejecutarCrearReserva() {
    if (!this.resIdCliente || !this.resIdHabitacion || !this.resFechaIn || !this.resFechaOut) {
      this.mostrarToast('error', 'Formulario Incompleto', 'Por favor diligencia todos los datos de la reserva.');
      return;
    }

    this.cargando.set(true);
    this.api.crearReserva(
      this.resIdCliente,
      this.resIdHabitacion,
      this.resFechaIn,
      this.resFechaOut,
      this.resNumHuespedes
    ).subscribe({
      next: resp => {
        this.cargando.set(false);
        this.reservaResultado.set(resp);
        this.historialReservas.update(list => [resp, ...list]);
        this.mostrarToast(
          'success',
          '¡Reserva Creada Exitosamente!',
          `Reserva #${resp.id_reserva} en ${resp.nombre_alojamiento} por $${resp.total.toLocaleString()} COP.`
        );
      },
      error: err => {
        this.cargando.set(false);
        const code = err.error?.code || 'ERROR';
        const msg = err.error?.message || 'Error en el procedimiento almacenado';
        this.mostrarToast('error', `Excepción Oracle XE [${code}]`, msg, code, 8000);
      }
    });
  }

  probarCasoExitoso() {
    this.resFechaIn = '2027-08-10';
    this.resFechaOut = '2027-08-15';
    this.resNumHuespedes = 2;
    if (this.habitaciones().length > 0) this.resIdHabitacion = this.habitaciones()[0].id_habitacion;
    if (this.clientes().length > 0) this.resIdCliente = this.clientes()[0].id;

    this.mostrarToast('info', 'Banco de Pruebas', 'Ejecutando Caso 1: Transacción válida con commit.');
    this.ejecutarCrearReserva();
  }

  probarErrorFechas() {
    this.resFechaIn = '2027-08-20';
    this.resFechaOut = '2027-08-15';
    this.resNumHuespedes = 2;
    if (this.habitaciones().length > 0) this.resIdHabitacion = this.habitaciones()[0].id_habitacion;
    if (this.clientes().length > 0) this.resIdCliente = this.clientes()[0].id;

    this.mostrarToast('warning', 'Banco de Pruebas', 'Provocando ORA-20001 (Fecha de salida anterior a check-in)...');
    this.ejecutarCrearReserva();
  }

  probarErrorCapacidad() {
    this.resFechaIn = '2027-09-01';
    this.resFechaOut = '2027-09-05';
    this.resNumHuespedes = 99;
    if (this.habitaciones().length > 0) this.resIdHabitacion = this.habitaciones()[0].id_habitacion;
    if (this.clientes().length > 0) this.resIdCliente = this.clientes()[0].id;

    this.mostrarToast('warning', 'Banco de Pruebas', 'Provocando ORA-20002 (99 huéspedes en habitación de 2-4 pers)...');
    this.ejecutarCrearReserva();
  }

  probarErrorSolapamiento() {
    this.resFechaIn = '2027-08-12';
    this.resFechaOut = '2027-08-14';
    this.resNumHuespedes = 1;
    if (this.habitaciones().length > 0) this.resIdHabitacion = this.habitaciones()[0].id_habitacion;
    if (this.clientes().length > 0) this.resIdCliente = this.clientes()[0].id;

    this.mostrarToast('warning', 'Banco de Pruebas', 'Provocando ORA-20003 (Solapamiento con reserva existente)...');
    this.ejecutarCrearReserva();
  }

  // ==========================================
  // Liquidación Masiva por Lotes (Cursor Explícito)
  // ==========================================
  ejecutarLiquidacion() {
    this.cargando.set(true);
    this.api.getLiquidaciones(this.liqMes, this.liqAnio, this.liqIdAlojamiento || undefined).subscribe({
      next: data => {
        this.cargando.set(false);
        this.liquidaciones.set(data);
        this.mostrarToast(
          'success',
          'Cursor Ejecutado',
          `Proceso masivo completado. ${data.length} alojamientos liquidados y persistidos en Oracle XE.`
        );
      },
      error: err => {
        this.cargando.set(false);
        this.mostrarToast('error', 'Error en Liquidación', err.error?.message || 'Fallo en cursor de liquidación');
      }
    });
  }

  exportarCSVLiquidacion() {
    const items = this.liquidacionesFiltradas();
    if (items.length === 0) {
      this.mostrarToast('warning', 'Sin Datos', 'No hay registros de liquidación para exportar.');
      return;
    }

    const headers = ['ID Alojamiento', 'Nombre Alojamiento', 'Mes', 'Anio', 'Total Reservas', 'Ingreso Hospedaje', 'Ingreso Servicios', 'Ingreso Bruto', 'Comision 10%', 'Neto 90%'];
    const rows = items.map(i => [
      i.id_alojamiento,
      `"${i.nombre_alojamiento}"`,
      i.mes,
      i.anio,
      i.total_reservas,
      i.ingreso_hospedaje,
      i.ingreso_servicios,
      i.ingreso_bruto,
      i.comision_plataforma,
      i.neto_pagar
    ]);

    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `Liquidacion_TurismoUQ_${this.liqMes}_${this.liqAnio}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    this.mostrarToast('info', 'Reporte Descargado', 'Archivo CSV exportado exitosamente.');
  }

  // ==========================================
  // Utilidades de Interfaz
  // ==========================================
  irACotizarDesdeAlojamiento(alojamientoId: number) {
    const hab = this.habitaciones().find(h => h.id_alojamiento === alojamientoId);
    if (hab) {
      this.cotIdHabitacion = hab.id_habitacion;
    }
    this.cambiarTab('cotizador');
    this.mostrarToast('info', 'Alojamiento Seleccionado', 'Habitación preseleccionada en el cotizador.');
  }

  getHabitacionSeleccionada(): HabitacionDetalle | undefined {
    return this.habitaciones().find(h => h.id_habitacion === Number(this.cotIdHabitacion));
  }

  getHabitacionReservaSeleccionada(): HabitacionDetalle | undefined {
    return this.habitaciones().find(h => h.id_habitacion === Number(this.resIdHabitacion));
  }
}
