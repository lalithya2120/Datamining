SELECT
    TO_CHAR(DATE_TRUNC('month', business_date), 'YYYY-MM') AS month,

    SUM(qty * unit_price) FILTER (
        WHERE line_type IN ('SALE', 'RETURN', 'DISCOUNT', 'VOID')
    ) AS correct_source_revenue,

    SUM(qty * unit_price) FILTER (
        WHERE line_type IN ('SALE', 'RETURN', 'VOID')
    ) AS revenue_without_discounts,

    SUM(qty * unit_price) FILTER (
        WHERE line_type = 'DISCOUNT'
    ) AS discount_amount,

    SUM(qty * unit_price) AS incorrect_all_lines_total

FROM sales_line_landing
WHERE business_date IN (
    DATE '2024-03-01',
    DATE '2024-12-01'
)
   OR business_date >= DATE '2024-03-01'
  AND business_date < DATE '2024-04-01'
   OR business_date >= DATE '2024-12-01'
  AND business_date < DATE '2025-01-01'
GROUP BY 1
ORDER BY 1;