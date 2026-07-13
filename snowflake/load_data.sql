-- =============================================
-- load_data.sql
-- Carga de leads_clean.csv y monthly_metrics.csv vía stage interno
-- =============================================

USE WAREHOUSE OPS_FUNNEL_WH;
USE DATABASE OPS_FUNNEL_DB;
USE SCHEMA ANALYTICS;

-- 1. Crear un file format reutilizable para ambos CSV
CREATE OR REPLACE FILE FORMAT csv_standard_format
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  NULL_IF = ('', 'NULL', 'null')      -- celdas vacías -> NULL (clave para deal_value)
  EMPTY_FIELD_AS_NULL = TRUE
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  TRIM_SPACE = TRUE;

-- 2. Crear un stage interno (almacenamiento temporal dentro de Snowflake)
CREATE OR REPLACE STAGE ops_funnel_stage
  FILE_FORMAT = csv_standard_format;

-- 3. Subir los archivos al stage
-- IMPORTANTE: este comando PUT se ejecuta desde SnowSQL (línea de comandos),
-- NO desde el editor web Snowsight. Si usas Snowsight, sube los archivos
-- manualmente con el botón "Upload files" al crear/usar el stage.
--
-- Desde SnowSQL (terminal), ejecutarías algo así:
-- PUT file:///ruta/local/leads_clean.csv @ops_funnel_stage;
-- PUT file:///ruta/local/monthly_metrics.csv @ops_funnel_stage;

-- 4. Verificar qué archivos quedaron en el stage
LIST @ops_funnel_stage;

-- 5. Cargar leads_clean.csv a la tabla
COPY INTO leads_clean
  FROM @ops_funnel_stage/leads_clean.csv
  FILE_FORMAT = (FORMAT_NAME = csv_standard_format)
  ON_ERROR = 'ABORT_STATEMENT';

-- 6. Cargar monthly_metrics.csv a la tabla
COPY INTO monthly_metrics
  FROM @ops_funnel_stage/monthly_metrics.csv
  FILE_FORMAT = (FORMAT_NAME = csv_standard_format)
  ON_ERROR = 'ABORT_STATEMENT';

-- 7. Verificación rápida de carga
SELECT COUNT(*) AS total_leads FROM leads_clean;              -- debería ser 380
SELECT COUNT(*) AS total_meses FROM monthly_metrics;           -- debería ser 24

SELECT * FROM leads_clean LIMIT 10;
SELECT * FROM monthly_metrics LIMIT 10;

-- 8. Chequeo específico de nulos esperados en deal_value
SELECT
    COUNT(*) AS total_filas,
    COUNT(deal_value) AS filas_con_valor,
    COUNT(*) - COUNT(deal_value) AS filas_nulas   -- debería dar 233
FROM leads_clean;
