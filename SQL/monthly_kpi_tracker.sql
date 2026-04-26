
SELECT 
    month,
    new_leads,
    total_closed_won,
    ROUND(conversion_rate * 100, 1) as conversion_rate_pct,
    avg_cycle_days,
    revenue
FROM monthly_metrics
ORDER BY month;
