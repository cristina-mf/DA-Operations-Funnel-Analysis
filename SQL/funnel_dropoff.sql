
SELECT 
    stage_reached,
    COUNT(*) as total_leads,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM leads), 1) as pct_of_total,
    SUM(CASE WHEN converted = 1 THEN 1 ELSE 0 END) as converted,
    ROUND(AVG(converted) * 100, 1) as conversion_rate_pct
FROM leads
GROUP BY stage_reached
ORDER BY total_leads DESC;
