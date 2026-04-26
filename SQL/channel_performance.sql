
SELECT 
    channel,
    COUNT(*) as total_leads,
    SUM(converted) as total_converted,
    ROUND(AVG(converted) * 100, 1) as conversion_rate_pct,
    ROUND(AVG(CASE WHEN deal_value IS NOT NULL 
          THEN deal_value END), 0) as avg_deal_value,
    ROUND(SUM(CASE WHEN converted = 1 
          THEN deal_value ELSE 0 END), 0) as total_revenue
FROM leads
GROUP BY channel
ORDER BY conversion_rate_pct DESC;
