-- =============================================
-- setup.sql
-- Configuración inicial: warehouse, database, schema y tablas
-- Proyecto: DA-Operations-Funnel-Analysis (migración a Snowflake)
-- =============================================

-- 1. Crear warehouse (motor de cómputo)
CREATE WAREHOUSE IF NOT EXISTS OPS_FUNNEL_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 300          -- se suspende tras 5 min de inactividad (evita gastar créditos)
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

-- 2. Crear base de datos
CREATE DATABASE IF NOT EXISTS OPS_FUNNEL_DB;

-- 3. Crear schema
CREATE SCHEMA IF NOT EXISTS OPS_FUNNEL_DB.ANALYTICS;

-- 4. Fijar contexto de trabajo para esta sesión
USE WAREHOUSE OPS_FUNNEL_WH;
USE DATABASE OPS_FUNNEL_DB;
USE SCHEMA ANALYTICS;

-- 5. Crear tabla leads_clean
CREATE OR REPLACE TABLE leads_clean (
    lead_id         VARCHAR(20)     NOT NULL,
    entry_date      DATE            NOT NULL,
    channel         VARCHAR(30)     NOT NULL,
    service_type    VARCHAR(30)     NOT NULL,
    stage_reached   VARCHAR(30)     NOT NULL,
    days_in_funnel  INTEGER         NOT NULL,
    deal_value      NUMBER(10,2),               -- permite NULL: leads sin cierre no tienen valor todavía
    assigned_rep    VARCHAR(20)     NOT NULL,
    converted       BOOLEAN         NOT NULL,
    month           VARCHAR(7)      NOT NULL     -- formato 'YYYY-MM', se deja como texto
);

-- 6. Crear tabla monthly_metrics
CREATE OR REPLACE TABLE monthly_metrics (
    month                   VARCHAR(7)   NOT NULL,   -- formato 'YYYY-MM'
    new_leads               INTEGER      NOT NULL,
    total_qualified         INTEGER      NOT NULL,
    total_proposals         INTEGER      NOT NULL,
    total_negotiations      INTEGER      NOT NULL,
    total_closed_won        INTEGER      NOT NULL,
    conversion_rate         NUMBER(5,3)  NOT NULL,
    avg_cycle_days          INTEGER      NOT NULL,
    revenue                 NUMBER(12,2) NOT NULL,
    lead_velocity_change    NUMBER(5,3)  NOT NULL
);

-- Verificación rápida
SHOW TABLES IN SCHEMA OPS_FUNNEL_DB.ANALYTICS;
