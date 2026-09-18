
WITH sales_from_object_store AS (
    SELECT
        bill_no,
        line_no,
        product_code,
        qty,
        unit_price,
        line_type,
        STRPTIME(
            REGEXP_EXTRACT(
                filename,
                'SALES_S[0-9]+_([0-9]{8})',
                1
            ),
            '%Y%m%d'
        )::DATE AS business_date
    FROM read_csv_auto(
        's3://annapurna-curated/sales/store=S01/year=2024/month=10/*.csv',
        filename=true
    )
)
SELECT
    st.store_name,
    COALESCE(pc.category_name, 'Unallocated / unmapped') AS category_name,
    SUM(sl.qty * sl.unit_price) AS revenue
FROM sales_from_object_store sl
JOIN pg.public.stores st
    ON st.store_id = 'S01'
LEFT JOIN pg.public.products p
    ON p.product_code = sl.product_code
   AND sl.business_date BETWEEN p.valid_from AND p.valid_to
LEFT JOIN pg.public.product_categories pc
    ON pc.category_id = p.category_id
WHERE sl.line_type IN ('SALE', 'RETURN', 'DISCOUNT', 'VOID')
GROUP BY
    st.store_name,
    COALESCE(pc.category_name, 'Unallocated / unmapped')
ORDER BY
    category_name;
