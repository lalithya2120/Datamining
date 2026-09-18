WITH categories AS (
    SELECT DISTINCT
        category_id,
        category_name
    FROM dim_product
)
SELECT
    s.store_name,
    c.category_name,
    d.day_name,
    TO_CHAR(d.year_month, 'YYYY-MM') AS month,
    SUM(r.revenue_amount) AS revenue
FROM dashboard_revenue_daily r
JOIN dim_store s
    ON s.store_id = r.store_id
JOIN categories c
    ON c.category_id = r.category_id
JOIN dim_date d
    ON d.business_date = r.business_date
GROUP BY
    s.store_name,
    c.category_name,
    d.day_name,
    d.year_month
ORDER BY
    month,
    s.store_name,
    c.category_name,
    d.day_name
LIMIT 30;