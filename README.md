# TurismoUQ · Plataforma Turística del Quindío
**Proyecto Integrador – Bases de Datos II **  
**Universidad del Quindío – Facultad de Ingeniería**

---

## 🏛️ Estructura del Repositorio

```text
turismo-uq/
├── database/
│   ├── 00_master_instalacion_completa.sql  # Script maestro: corre de arriba a abajo en base limpia
│   ├── modelo_y_decisiones_diseno.md       # Documento técnico oficial (Modelo 14 tablas y decisiones)
│   ├── entrega 1/
│   │   ├── 01_ddl_esquema_completo.sql    # DDL con PK, FK, CHECK, NOT NULL y UNIQUE (14 entidades)
│   │   ├── 02_carga_datos_minimos.sql     # Población reproducible (12 mun, 60 aloj, 400 hab, 3k cli, 25k res, 40k serv)
│   │   ├── 03_tablespace_historico.sql    # TBS_HISTORICO_RESERVAS y reubicación de tablas/índices
│   │   ├── 04_consultas_analisis.sql      # 8 Consultas analíticas (PIVOT, ROLLUP, RANK, LAG, MV, etc.)
│   │   └── justificacion_tablespace.md    # Sustentación técnica de separación física de I/O
│   └── entrega 2/
│       ├── 01_ajuste_temporadas_tarifas.sql # Estandarización a Temporada Alta y Baja (800 tarifas)
│       ├── 02_pkg_turismo_reservas_spec.sql # Especificación del paquete PL/SQL
│       ├── 03_pkg_turismo_reservas_body.sql # Cuerpo del paquete (fn_valor_estadia, sp_crear_reserva, etc.)
│       ├── 04_triggers.sql                  # Triggers: auditoría a nivel de sentencia y anti-mutante
│       └── 05_test_entrega2.sql             # Batería de pruebas automatizadas idempotente (100% exitosa)
├── backend/                                 # Spring Boot 3.4 + Java 21 LTS + Oracle JDBC
│   ├── src/main/java/com/turismouq/app/
│   │   ├── config/                          # Configuración CORS y DataSource
│   │   ├── controller/                      # Endpoints REST para reservas, cotizaciones, analítica y catálogo
│   │   ├── dto/
│   │   │   ├── request/                     # Records de petición
│   │   │   └── response/                    # Records de respuesta
│   │   ├── entity/                          # Entidades JPA que mapean el esquema de Oracle XE
│   │   ├── exception/                       # Manejador global y mapeo de errores ORA-2000x a HTTP
│   │   ├── repository/                      # Repositorios JPA y consultas nativas con JdbcTemplate
│   │   └── service/                         # Lógica de negocio e invocación de paquetes PL/SQL
│   └── pom.xml
├── frontend/                                # Angular 19 + HTML5 + CSS moderno (Signals & Chart.js)
│   └── src/app/                             # Dashboard interactivo para sustentación en vivo
├── run_project.ps1                          # Script de arranque en 1 clic
└── .agents/                                 # Skills y agentes configurados para ahorro de cuota
```

---

## 🚀 Puesta en Marcha

### Prerrequisitos
* **Oracle Database 21c XE** instalado localmente con el esquema `TURISMO_UQ` en la PDB `XEPDB1`.
* **Java 21 LTS**.
* **Node.js LTS (v24+)**.

### Ejecución Rápida
Ejecuta el script PowerShell incluido en la raíz:
```powershell
.\run_project.ps1
```

O arranca cada servicio manualmente:

1. **Backend (Puerto 8080):**
   ```powershell
   cd backend
   .\mvnw.cmd spring-boot:run
   ```

2. **Frontend (Puerto 4200):**
   ```powershell
   cd frontend
   npm start
   ```

Abre tu navegador en: **`http://localhost:4200`**
