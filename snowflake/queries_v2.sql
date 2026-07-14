-- =============================================================
-- queries_v2.sql
-- Queries migrated and enhanced for Snowflake
-- Project: DA-Operations-Funnel-Analysis
-- Each query includes: original version (SQLite) + enhanced
-- version leveraging Snowflake window functions / QUALIFY
-- =============================================================

USE DATABASE OPS_FUNNEL_DB;
USE SCHEMA ANALYTICS;


-- =============================================================
-- 1. BOTTLENECK ANALYSIS
-- Original: aggregated averages by stage and channel.
-- Enhancement: RANK() + QUALIFY to automatically isolate the
--              #1 bottleneck stage for each channel.
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

-- Enhanced
-- Note: 'Closed_Won' is excluded from the ranking because
-- days_in_funnel is cumulative — a lead that reached close
-- necessarily accumulated more days than one that stalled
-- earlier, so Closed_Won would always show up as the "bottleneck"
-- without actually being one. What we really want to identify
-- is where leads that HAVE NOT closed yet are getting stuck.
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
WHERE stage_reached != 'Closed_Won'
GROUP BY channel, stage_reached
QUALIFY bottleneck_rank = 1
ORDER BY avg_days DESC;


-- =============================================================
-- 2. CHANNEL PERFORMANCE
-- Original: channels ordered by conversion rate.
-- Enhancement: DENSE_RANK() + QUALIFY to keep only the Top 3,
--              plus each channel's % contribution to total revenue.
-- =============================================================

-- Original
-- Note: converted is BOOLEAN in Snowflake, so it's cast to
-- INT (::INT) before summing/averaging (SQLite handled this
-- implicitly).
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

-- Enhanced
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
-- Original: % of total leads per stage.
-- Enhancement: LAG() to calculate the real drop-off rate between
--              consecutive funnel stages.
-- Note: stage_reached represents the FURTHEST stage each lead
--       reached, so this is an approximation of true drop-off
--       (not a traditional cumulative funnel count).
-- =============================================================

-- Original
-- Note: converted is BOOLEAN, compared with TRUE (not 1) and
-- cast to INT (::INT) before averaging.
SELECT
    stage_reached,
    COUNT(*) AS total_leads,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM leads_clean), 1) AS pct_of_total,
    SUM(CASE WHEN converted = TRUE THEN 1 ELSE 0 END) AS converted,
    ROUND(AVG(converted::INT) * 100, 1) AS conversion_rate_pct
FROM leads_clean
GROUP BY stage_reached
ORDER BY total_leads DESC;

-- Enhanced
-- Note: stage_reached buckets are mutually exclusive (each lead is
-- counted only once, at the furthest stage it reached), so raw
-- total_leads per stage is NOT cumulative. Applying LAG() directly
-- on that produces nonsensical negative "drop-off" percentages once
-- a later stage's bucket happens to hold more leads than an earlier
-- one. We first convert to a CUMULATIVE "reached at least this
-- stage" count, then compute the real drop-off between stages.
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
        COUNT(*) AS leads_at_this_stage
    FROM leads_clean
    GROUP BY stage_reached
),
funnel_cumulative AS (
    SELECT
        stage_reached,
        stage_order,
        leads_at_this_stage,
        -- leads that reached AT LEAST this stage = sum of this
        -- stage's bucket + every later stage's bucket
        SUM(leads_at_this_stage) OVER (
            ORDER BY stage_order DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS leads_reached_at_least
    FROM funnel_ordered
)
SELECT
    stage_reached,
    stage_order,
    leads_reached_at_least,
    LAG(leads_reached_at_least) OVER (ORDER BY stage_order) AS leads_previous_stage,
    ROUND(
        (1 - leads_reached_at_least * 1.0
         / NULLIF(LAG(leads_reached_at_least) OVER (ORDER BY stage_order), 0)) * 100
    , 1) AS drop_off_pct_vs_previous_stage
FROM funnel_cumulative
ORDER BY stage_order;


-- =============================================================
-- 4. MONTHLY KPI TRACKER
-- Original: each month's figures shown in isolation.
-- Enhancement: LAG() for month-over-month growth + AVG() OVER()
--              for a 3-month moving average.
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

-- Enhanced
SELECT
    month,
    new_leads,
    total_closed_won,
    ROUND(conversion_rate * 100, 1) AS conversion_rate_pct,
    avg_cycle_days,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS revenue_previous_month,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month)) * 100.0
        / NULLIF(LAG(revenue) OVER (ORDER BY month), 0)
    , 1) AS revenue_growth_pct,
    ROUND(
        AVG(revenue) OVER (
            ORDER BY month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        )
    , 0) AS revenue_3m_moving_avg
FROM monthly_metrics
ORDER BY month;
