-- Part (c): dashboard star schema

DROP TABLE IF EXISTS dashboard_revenue_daily;
DROP TABLE IF EXISTS fact_revenue;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_store;

-- Store details live once here, never on every revenue line.
CREATE TABLE dim_store AS
SELECT
    store_id,
    store_name,
    address_line,
    city,
    state,
    region,
    floor_area_sqft,
    opened_on
FROM stores;

ALTER TABLE dim_store
    ADD PRIMARY KEY (store_id);


-- A product is identified by product_sk, not product_code alone.
-- Product validity dates are retained for auditability.
CREATE TABLE dim_product (
    product_sk    BIGINT PRIMARY KEY,
    product_code  TEXT,
    product_name  TEXT NOT NULL,
    category_id   TEXT NOT NULL,
    category_name TEXT NOT NULL,
    department    TEXT,
    brand         TEXT,
    pack_size     TEXT,
    uom           TEXT,
    valid_from    DATE,
    valid_to      DATE
);

INSERT INTO dim_product (
    product_sk, product_code, product_name, category_id,
    category_name, department, brand, pack_size, uom,
    valid_from, valid_to
)
SELECT
    p.product_sk,
    p.product_code,
    p.product_name,
    p.category_id,
    pc.category_name,
    pc.department,
    p.brand,
    p.pack_size,
    p.uom,
    p.valid_from,
    p.valid_to
FROM products p
JOIN product_categories pc
    ON pc.category_id = p.category_id;

-- Required where a bill-level discount has no product/category.
INSERT INTO dim_product (
    product_sk, product_code, product_name, category_id,
    category_name, department, valid_from, valid_to
)
VALUES (
    -1, NULL, 'Unallocated discount', 'UNALLOCATED',
    'Unallocated discount', 'Adjustments',
    DATE '1900-01-01', DATE '9999-12-31'
);

-- Keeps unmapped product data visible rather than silently dropping it.
INSERT INTO dim_product (
    product_sk, product_code, product_name, category_id,
    category_name, department, valid_from, valid_to
)
VALUES (
    -2, NULL, 'Unmapped product', 'UNMAPPED',
    'Unmapped product', 'Data quality',
    DATE '1900-01-01', DATE '9999-12-31'
);


-- Calendar attributes are stored once per business date.
CREATE TABLE dim_date (
    business_date DATE PRIMARY KEY,
    day_of_week   SMALLINT NOT NULL,
    day_name      TEXT NOT NULL,
    month_number  SMALLINT NOT NULL,
    month_name    TEXT NOT NULL,
    calendar_year INTEGER NOT NULL,
    year_month    DATE NOT NULL
);

INSERT INTO dim_date (
    business_date, day_of_week, day_name, month_number,
    month_name, calendar_year, year_month
)
SELECT
    day::DATE,
    EXTRACT(DOW FROM day)::SMALLINT,
    TO_CHAR(day, 'FMDay'),
    EXTRACT(MONTH FROM day)::SMALLINT,
    TO_CHAR(day, 'FMMonth'),
    EXTRACT(YEAR FROM day)::INTEGER,
    DATE_TRUNC('month', day)::DATE
FROM generate_series(
    (SELECT MIN(business_date) FROM sales_line_landing),
    (SELECT MAX(business_date) FROM sales_line_landing),
    INTERVAL '1 day'
) AS calendar(day);


-- Atomic fact table: one row per bill line.
-- TAX and TENDER are excluded.
-- SALE, RETURN, DISCOUNT, and VOID remain so cancelled bills net to zero.
CREATE TABLE fact_revenue (
    bill_no        TEXT NOT NULL,
    line_no        TEXT NOT NULL,
    business_date  DATE NOT NULL REFERENCES dim_date(business_date),
    store_id       TEXT NOT NULL REFERENCES dim_store(store_id),
    product_sk     BIGINT NOT NULL REFERENCES dim_product(product_sk),
    line_type      TEXT NOT NULL,
    qty            NUMERIC NOT NULL,
    unit_price     NUMERIC NOT NULL,
    revenue_amount NUMERIC NOT NULL,
    PRIMARY KEY (bill_no, line_no)
);

INSERT INTO fact_revenue (
    bill_no, line_no, business_date, store_id, product_sk,
    line_type, qty, unit_price, revenue_amount
)
SELECT
    l.bill_no,
    l.line_no,
    l.business_date,
    l.store_id,

    CASE
        WHEN l.line_type = 'DISCOUNT' THEN -1
        ELSE COALESCE(p.product_sk, -2)
    END AS product_sk,

    l.line_type,
    l.qty,
    l.unit_price,
    l.qty * l.unit_price AS revenue_amount
FROM sales_line_landing l
LEFT JOIN products p
    ON p.product_code = l.product_code
   AND l.business_date BETWEEN p.valid_from AND p.valid_to
WHERE l.line_type IN ('SALE', 'RETURN', 'DISCOUNT', 'VOID');

CREATE INDEX ix_fact_revenue_store_date
    ON fact_revenue (store_id, business_date);

CREATE INDEX ix_fact_revenue_product_date
    ON fact_revenue (product_sk, business_date);


-- Small daily aggregate for fast dashboard slicing.
CREATE TABLE dashboard_revenue_daily AS
SELECT
    f.business_date,
    f.store_id,
    p.category_id,
    SUM(f.revenue_amount) AS revenue_amount
FROM fact_revenue f
JOIN dim_product p
    ON p.product_sk = f.product_sk
GROUP BY
    f.business_date,
    f.store_id,
    p.category_id;

ALTER TABLE dashboard_revenue_daily
    ADD PRIMARY KEY (business_date, store_id, category_id);

CREATE INDEX ix_dashboard_revenue_store_date
    ON dashboard_revenue_daily (store_id, business_date);

CREATE INDEX ix_dashboard_revenue_category_date
    ON dashboard_revenue_daily (category_id, business_date);