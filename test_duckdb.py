import duckdb

con = duckdb.connect("annapurna.duckdb")

con.execute("INSTALL httpfs;")
con.execute("LOAD httpfs;")

con.execute("""
SET s3_endpoint='localhost:9000';
SET s3_access_key_id='minioadmin';
SET s3_secret_access_key='minioadmin';
SET s3_use_ssl=false;
SET s3_url_style='path';
""")

result = con.execute("""
    SELECT COUNT(*) AS rows_read
    FROM read_csv_auto(
        's3://annapurna-curated/sales/store=S01/year=2024/month=01/*.csv',
        hive_partitioning=true
    )
""").fetchone()

print("Rows read from MinIO:", result[0])