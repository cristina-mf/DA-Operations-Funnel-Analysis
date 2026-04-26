
SELECT 
    stage_reached,
    channel,
    ROUND(AVG(days_in_funnel), 1) as avg_days,
    MIN(days_in_funnel) as min_days,
    MAX(days_in_funnel) as max_days,
    COUNT(*) as total_leads
FROM leads
GROUP BY stage_reached, channel
ORDER BY avg_days DESC;
