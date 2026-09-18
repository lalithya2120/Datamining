The query was federated: DuckDB read sales files directly from MinIO through

READ\_CSV\_AUTO and read stores, products, and product\_categories directly from

the attached PostgreSQL database (pg.public). No CREATE TABLE, INSERT, or copy

operation was used.



EXPLAIN ANALYZE showed READ\_CSV\_AUTO against the S3 path

sales/store=S01/year=2024/month=10 and Total Files Read: 31. The object-store

scan projected only product\_code, qty, unit\_price, line\_type, and filename.



The same plan showed PostgreSQL-source table scans for stores (1 row after the

store\_id='S01' filter), products (1,224 rows), and product\_categories

(14 rows). DuckDB then performed the FILTER, HASH\_JOIN operators, and final

revenue aggregation. The product join included product\_code plus the business

date within valid\_from and valid\_to, preventing reused product codes from

joining to the wrong product.

