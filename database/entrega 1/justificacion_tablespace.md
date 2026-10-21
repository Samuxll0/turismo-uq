# Justificación Técnica de Arquitectura: Tablespace Dedicado para el Histórico de Reservas

**Asignatura:** Bases de Datos II (Código 12338)  
**Proyecto:** TurismoUQ – Plataforma de Reservas Turísticas del Quindío  
**Componente:** Entrega 1 – Administración de Almacenamiento y Tablespaces  

---

## 1. Introducción y Contexto del Problema

En un sistema transaccional de reservas como **TurismoUQ**, la base de datos almacena dos tipos fundamentales de información con características operativas, patrones de acceso y tasas de crecimiento radicalmente opuestas:

1. **Datos Maestros y Dimensionales (OLTP de baja volatilidad):**
   - Tablas: `MUNICIPIO`, `TIPO_ALOJAMIENTO`, `ALOJAMIENTO`, `HABITACION`, `TEMPORADA`, `SERVICIO`, `USUARIO_SISTEMA`.
   - Crecimiento: Lento y acotado (los 12 municipios son fijos, la oferta de alojamientos y habitaciones cambia esporádicamente).
   - Patrón de I/O: Lecturas frecuentes y masivas (consultas de catálogo, disponibilidad y filtros).

2. **Datos Transaccionales e Históricos (OLTP / DWH de alta volatilidad):**
   - Tablas: `RESERVA`, `RESERVA_HABITACION`, `RESERVA_SERVICIO`, `PAGO`.
   - Crecimiento: Rápido y acumulativo (en el volumen mínimo del proyecto se exigen 25.000 reservas, 40.000 consumos de servicios y 25.000 pagos repartidos entre 2024 y 2026).
   - Patrón de I/O: Alto volumen de escrituras concurrentes (`INSERT`, `UPDATE`), escaneos por rangos de fecha y consultas analíticas pesadas.

Alojar ambas naturalezas de datos dentro del tablespace por defecto (`USERS`) introduce serios problemas de contención de disco, fragmentación de segmentos y riesgos de indisponibilidad.

---

## 2. Argumentación Técnica de la Separación Física en `TBS_HISTORICO_RESERVAS`

### 2.1 Aislamiento de I/O y Reducción de Cuellos de Botella
Al ubicar las tablas transaccionales en un datafile específico (`TBS_HIST_RESERVAS01.DBF`):
- Los procesos servidores de Oracle que escriben reservas y pagos no compiten por los mismos bloques ni por el mismo espacio contiguo del datafile `USERS01.DBF`.
- En un entorno de producción, este tablespace puede montarse sobre un disco físico o volumen de almacenamiento de estado sólido (NVMe/SSD) de alto rendimiento, mientras que tablas estáticas pueden residir en almacenamiento estándar, optimizando el costo/rendimiento del storage.

### 2.2 Estrategia Diferenciada de Respaldos y Recuperación (RMAN)
En Oracle Database, la granularidad mínima de respaldo lógico-físico después del bloque es el *Tablespace*:
- **Copias de seguridad incrementales frecuentes:** `TBS_HISTORICO_RESERVAS` puede respaldarse a diario o varias veces al día con RMAN debido a su constante mutación transaccional.
- **Tablas maestras estables:** El tablespace `USERS` puede respaldarse con menor frecuencia (ej. semanal), ahorrando tiempo de procesamiento y espacio en el repositorio de backups.
- **Tolerancia a fallos (*Point-in-Time Recovery*):** Si ocurriese una corrupción física en el archivo de datos del histórico, el administrador puede realizar una recuperación puntual a nivel de tablespace (`TSPIR` - *Tablespace Point-in-Time Recovery*) sin poner fuera de línea los catálogos maestros de la plataforma.

### 2.3 Mantenimiento y Desfragmentación sin Bloqueo
- Las operaciones periódicas como la reconstrucción de índices masivos (`ALTER INDEX REBUILD`) o reorganización de tablas por borrado masivo de auditorías pueden ejecutarse dentro de `TBS_HISTORICO_RESERVAS` sin impactar la memoria contigua de los segmentos de usuarios y catálogos maestros.

### 2.4 Habilitación para Compresión y Archivado Histórico
- A medida que las reservas de años anteriores (ej. 2024) pasan de un estado transaccional activo a un estado de consulta histórica o auditoría, Oracle permite colocar dicho tablespace en modo de solo lectura (`READ ONLY`) o activar compresión avanzada (*Advanced Row Compression* o *Hybrid Columnar Compression*):
  ```sql
  ALTER TABLESPACE TBS_HISTORICO_RESERVAS READ ONLY;
  ```
- Al estar en `READ ONLY`, RMAN ya no necesita respaldarlo en cada ciclo completo, reduciendo sustancialmente las ventanas de backup de la organización.

---

## 3. Conclusión
La creación del tablespace `TBS_HISTORICO_RESERVAS` y la reubicación de las tablas `RESERVA`, `RESERVA_HABITACION`, `RESERVA_SERVICIO` y `PAGO` responde a las mejores prácticas de administración de bases de datos empresariales en Oracle 21c, asegurando escalabilidad, aislamiento de rendimiento y continuidad del negocio para la plataforma **TurismoUQ**.
