-- ============================================================================
-- PROYECTO INTEGRADOR: TURISMOUQ - BASES DE DATOS II
-- SCRIPT MAESTRO DE EJECUCION INTEGRAL Y DESPLIEGUE EN BASE LIMPIA
-- ARCHIVO: database/00_master_instalacion_completa.sql
-- MOTOR: ORACLE DATABASE 21c EXPRESS EDITION (PDB: XEPDB1)
-- ESQUEMA: TURISMO_UQ
--
-- CUMPLE LA REGLA OFICIAL DEL CURSO:
-- "Un script que no corre de arriba abajo en una base limpia no se califica."
-- ============================================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = TURISMO_UQ;

SET ECHO OFF;
SET FEEDBACK ON;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET TIMING ON;

PROMPT ============================================================================
PROMPT === PROYECTO INTEGRADOR BDII: TURISMOUQ - INSTALACION COMPLETA           ===
PROMPT ============================================================================

PROMPT ----------------------------------------------------------------------------
PROMPT [PASO 1/9] Creacion del Modelo Relacional Limpio (14 Entidades y Reglas)
PROMPT ----------------------------------------------------------------------------
@@"entrega 1/01_ddl_esquema_completo.sql";

PROMPT ----------------------------------------------------------------------------
PROMPT [PASO 2/9] Poblacion y Generacion del Volumen Minimo de Datos
PROMPT           (12 mun, 60 aloj, 400 hab, 3.000 cli, 25.000 res, 40.000 serv)
PROMPT ----------------------------------------------------------------------------
@@"entrega 1/02_carga_datos_minimos.sql";

PROMPT ----------------------------------------------------------------------------
PROMPT [PASO 3/9] Configuracion de Tablespace Dedicado TBS_HISTORICO_RESERVAS
PROMPT ----------------------------------------------------------------------------
@@"entrega 1/03_tablespace_historico.sql";

PROMPT ----------------------------------------------------------------------------
PROMPT [PASO 4/9] Verificacion de las Ocho Consultas Analiticas Obligatorias y MV
PROMPT ----------------------------------------------------------------------------
@@"entrega 1/04_consultas_analisis.sql";

PROMPT ----------------------------------------------------------------------------
PROMPT [PASO 5/9] Ajuste de Periodos de Temporada Alta y Recalculo de Tarifas (+40%)
PROMPT ----------------------------------------------------------------------------
@@"entrega 2/01_ajuste_temporadas_tarifas.sql";

PROMPT ----------------------------------------------------------------------------
PROMPT [PASO 6/9] Compilacion de Triggers (Auditoria de Sentencia y Anti-Mutante)
PROMPT ----------------------------------------------------------------------------
@@"entrega 2/04_triggers.sql";

PROMPT ----------------------------------------------------------------------------
PROMPT [PASO 7/9] Compilacion de Especificacion del Paquete PKG_TURISMO_RESERVAS
PROMPT ----------------------------------------------------------------------------
@@"entrega 2/02_pkg_turismo_reservas_spec.sql";

PROMPT ----------------------------------------------------------------------------
PROMPT [PASO 8/9] Compilacion de Cuerpo del Paquete PKG_TURISMO_RESERVAS
PROMPT ----------------------------------------------------------------------------
@@"entrega 2/03_pkg_turismo_reservas_body.sql";

PROMPT ----------------------------------------------------------------------------
PROMPT [PASO 9/9] Ejecucion de Bateria Automatizada de Pruebas PL/SQL (Entrega 2)
PROMPT ----------------------------------------------------------------------------
@@"entrega 2/05_test_entrega2.sql";

PROMPT ============================================================================
PROMPT === VERIFICACION DE ESTADO DE OBJETOS EN EL ESQUEMA TURISMO_UQ           ===
PROMPT ============================================================================

COLUMN OBJECT_NAME FORMAT A30;
COLUMN OBJECT_TYPE FORMAT A20;
COLUMN STATUS FORMAT A10;

SELECT object_name, object_type, status
FROM user_objects
WHERE object_type IN ('PACKAGE', 'PACKAGE BODY', 'TRIGGER', 'TABLE', 'INDEX', 'VIEW', 'MATERIALIZED VIEW')
  AND status = 'INVALID'
ORDER BY object_type, object_name;

PROMPT (Si la consulta anterior devuelve 0 filas, todos los objetos compilaron con 100% de exito)

PROMPT ============================================================================
PROMPT === CONTEO FINAL DE REGISTROS EN TABLAS PRINCIPALES                      ===
PROMPT ============================================================================

SELECT 'MUNICIPIOS' AS ENTIDAD, COUNT(*) AS TOTAL FROM MUNICIPIO
UNION ALL
SELECT 'ALOJAMIENTOS', COUNT(*) FROM ALOJAMIENTO
UNION ALL
SELECT 'HABITACIONES', COUNT(*) FROM HABITACION
UNION ALL
SELECT 'CLIENTES', COUNT(*) FROM CLIENTE
UNION ALL
SELECT 'RESERVAS', COUNT(*) FROM RESERVA
UNION ALL
SELECT 'RESERVA_HABITACION', COUNT(*) FROM RESERVA_HABITACION
UNION ALL
SELECT 'RESERVA_SERVICIO', COUNT(*) FROM RESERVA_SERVICIO
UNION ALL
SELECT 'PAGOS', COUNT(*) FROM PAGO
UNION ALL
SELECT 'TARIFAS', COUNT(*) FROM TARIFA
UNION ALL
SELECT 'PERIODOS TEMPORADA', COUNT(*) FROM PERIODO_TEMPORADA
UNION ALL
SELECT 'USUARIOS SISTEMA', COUNT(*) FROM USUARIO_SISTEMA;

PROMPT ============================================================================
PROMPT === INSTALACION, POBLACION Y VERIFICACION COMPLETADA EXITOSAMENTE        ===
PROMPT ============================================================================
