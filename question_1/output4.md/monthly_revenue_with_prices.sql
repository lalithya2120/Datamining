SELECT
    :'report_month'::date AS reporting_month,
    s.store_name,
    p.category_name,
    SUM(v.revenue_at_effective_price) AS revenue_using_price_at_time_of_sale
FROM v_revenue_with_effective_price v
JOIN dim_store s
    ON s.store_id = v.store_id
JOIN dim_product p
    ON p.product_sk = v.product_sk
WHERE v.business_date >= :'report_month'::date
  AND v.business_date < (:'report_month'::date + INTERVAL '1 month')
GROUP BY
    s.store_name,
    p.category_name
ORDER BY
    s.store_name,
    p.category_name;