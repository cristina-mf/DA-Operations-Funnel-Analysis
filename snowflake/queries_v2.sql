-- =============================================================
-- queries_v2.sql
-- Consultas migradas y mejoradas para Snowflake
-- Proyecto: DA-Operations-Funnel-Analysis
-- Cada consulta incluye: versión original (SQLite) + versión
-- mejorada aprovechando funciones de ventana / QUALIFY de Snowflake
-- =============================================================

USE DATABASE OPS_FUNNEL_DB;
USE SCHEMA ANALYTICS;


-- =============================================================
-- 1. BOTTLENECK ANALYSIS
-- Original: promedios agregados por etapa y canal.
-- Mejora: RANK() + QUALIFY para aislar el cuello de botella #1
--         de cada canal automáticamente.
-- =============================================================

-- Original
SELECT
    stage_reached,
    channel,
    ROUND(AVG(days_in_funnel), 1) AS avg_days,
    MIN(days_in_funnel) AS min_days,
    MAX(days_in_funnel) AS max_days,
    COUNT(*) AS total_leads
FROM leads_clean
GROUP BY stage_reached, channel
ORDER BY avg_days DESC;

-- Mejorada
SELECT
    channel,
    stage_reached,
    ROUND(AVG(days_in_funnel), 1) AS avg_days,
    COUNT(*) AS total_leads,
    RANK() OVER (
        PARTITION BY channel
        ORDER BY AVG(days_in_funnel) DESC
    ) AS bottleneck_rank
FROM leads_clean
GROUP BY channel, stage_reached
QUALIFY bottleneck_rank = 1
ORDER BY avg_days DESC;


-- =============================================================
-- 2. CHANNEL PERFORMANCE
-- Original: canales ordenados por tasa de conversión.
-- Mejora: DENSE_RANK() + QUALIFY para quedarnos con el Top 3,
--         y % de contribución de cada canal al ingreso total.
-- =============================================================

-- Original
-- Nota: converted es BOOLEAN en Snowflake, por lo que se convierte a
-- INT (::INT) antes de sumarlo/promediarlo (SQLite lo hacía implícitamente).
SELECT
    channel,
    COUNT(*) AS total_leads,
    SUM(converted::INT) AS total_converted,
    ROUND(AVG(converted::INT) * 100, 1) AS conversion_rate_pct,
    ROUND(AVG(CASE WHEN deal_value IS NOT NULL
          THEN deal_value END), 0) AS avg_deal_value,
    ROUND(SUM(CASE WHEN converted = TRUE
          THEN deal_value ELSE 0 END), 0) AS total_revenue
FROM leads_clean
GROUP BY channel
ORDER BY conversion_rate_pct DESC;

-- Mejorada
SELECT
    channel,
    COUNT(*) AS total_leads,
    SUM(converted::INT) AS total_converted,
    ROUND(AVG(converted::INT) * 100, 1) AS conversion_rate_pct,
    ROUND(AVG(CASE WHEN deal_value IS NOT NULL
          THEN deal_value END), 0) AS avg_deal_value,
    ROUND(SUM(CASE WHEN converted = TRUE
          THEN deal_value ELSE 0 END), 0) AS total_revenue,
    ROUND(
        SUM(CASE WHEN converted = TRUE THEN deal_value ELSE 0 END) * 100.0
        / SUM(SUM(CASE WHEN converted = TRUE THEN deal_value ELSE 0 END)) OVER (), 1
    ) AS pct_of_total_revenue,
    DENSE_RANK() OVER (ORDER BY AVG(converted::INT) DESC) AS conversion_rank
FROM leads_clean
GROUP BY channel
QUALIFY conversion_rank <= 3
ORDER BY conversion_rank;


-- =============================================================
-- 3. FUNNEL DROPOFF
-- Original: % del total de leads por etapa.
-- Mejora: LAG() para calcular la tasa de abandono real entre
--         etapas consecutivas del embudo.
-- Nota: stage_reached representa la etapa MÁS AVANZADA alcanzada
--       por cada lead, así que esto es una aproximación del
--       abandono real (no un conteo acumulado tradicional).
-- =============================================================

-- Original
-- Nota: converted es BOOLEAN, se compara con TRUE (no con 1) y se
-- convierte a INT (::INT) antes de promediar.
SELECT
    stage_reached,
    COUNT(*) AS total_leads,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM leads_clean), 1) AS pct_of_total,
    SUM(CASE WHEN converted = TRUE THEN 1 ELSE 0 END) AS converted,
    ROUND(AVG(converted::INT) * 100, 1) AS conversion_rate_pct
FROM leads_clean
GROUP BY stage_reached
ORDER BY total_leads DESC;

-- Mejorada
WITH funnel_ordered AS (
    SELECT
        stage_reached,
        CASE stage_reached
            WHEN 'Lead'        THEN 1
            WHEN 'Qualified'   THEN 2
            WHEN 'Proposal'    THEN 3
            WHEN 'Negotiation' THEN 4
            WHEN 'Closed_Won'  THEN 5
        END AS stage_order,
        COUNT(*) AS total_leads
    FROM leads_clean
    GROUP BY stage_reached
)
SELECT
    stage_reached,
    stage_order,
    total_leads,
    LAG(total_leads) OVER (ORDER BY stage_order) AS leads_etapa_anterior,
    ROUND(
        (1 - total_leads * 1.0 / NULLIF(LAG(total_leads) OVER (ORDER BY stage_order), 0)) * 100
    , 1) AS drop_off_pct_vs_etapa_anterior
FROM funnel_ordered
ORDER BY stage_order;


-- =============================================================
-- 4. MONTHLY KPI TRACKER
-- Original: dato de cada mes de forma aislada.
-- Mejora: LAG() para crecimiento mes a mes + AVG() OVER()
--         para promedio móvil de 3 meses.
-- =============================================================

-- Original
SELECT
    month,
    new_leads,
    total_closed_won,
    ROUND(conversion_rate * 100, 1) AS conversion_rate_pct,
    avg_cycle_days,
    revenue
FROM monthly_metrics
ORDER BY month;

-- Mejorada
SELECT
    month,
    new_leads,
    total_closed_won,
    ROUND(conversion_rate * 100, 1) AS conversion_rate_pct,
    avg_cycle_days,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS revenue_mes_anterior,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month)) * 100.0
        / NULLIF(LAG(revenue) OVER (ORDER BY month), 0)
    , 1) AS revenue_growth_pct,
    ROUND(
        AVG(revenue) OVER (
            ORDER BY month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        )
    , 0) AS revenue_promedio_movil_3m
FROM monthly_metrics
ORDER BY month;
