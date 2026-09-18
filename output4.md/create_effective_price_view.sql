CREATE OR REPLACE VIEW v_revenue_with_effective_price AS
SELECT
    f.bill_no,
    f.line_no,
    f.business_date,
    f.store_id,
    f.product_sk,
    f.line_type,
    f.qty,

    CASE
        WHEN f.line_type = 'DISCOUNT' THEN f.unit_price
        ELSE pr.selling_price
    END AS effective_selling_price,

    CASE
        WHEN f.line_type = 'DISCOUNT' THEN f.revenue_amount
        ELSE f.qty * pr.selling_price
    END AS revenue_at_effective_price

FROM fact_revenue f
LEFT JOIN price_revisions pr
    ON pr.product_sk = f.product_sk
   AND f.business_date BETWEEN pr.effective_from AND pr.effective_to;