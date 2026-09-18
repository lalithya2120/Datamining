import csv
from decimal import Decimal
from pathlib import Path

import psycopg

OUTPUT = Path("output(f)")
OUTPUT.mkdir(exist_ok=True)

def money(value):
    return Decimal(str(value or 0)).quantize(Decimal("0.01"))

def same(a, b):
    return abs(money(a) - money(b)) <= Decimal("0.01")

finance = {}

with open("finance_monthly.csv", newline="", encoding="utf-8-sig") as file:
    for row in csv.DictReader(file):
        finance[row["month"]] = money(row["revenue_inr"])

SQL = """
WITH printed_revenue AS (
    SELECT
        TO_CHAR(DATE_TRUNC('month', business_date), 'YYYY-MM') AS month,
        SUM(revenue_amount) AS printed_revenue
    FROM fact_revenue
    GROUP BY 1
),
authoritative_revenue AS (
    SELECT
        TO_CHAR(DATE_TRUNC('month', business_date), 'YYYY-MM') AS month,
        SUM(revenue_at_effective_price) AS authoritative_revenue,
        COUNT(*) FILTER (
            WHERE line_type <> 'DISCOUNT'
              AND effective_selling_price IS NULL
        ) AS missing_price_lines
    FROM v_revenue_with_effective_price
    GROUP BY 1
),
all_lines_diagnostic AS (
    SELECT
        TO_CHAR(DATE_TRUNC('month', business_date), 'YYYY-MM') AS month,
        SUM(qty * unit_price) AS all_lines_total
    FROM sales_line_landing
    GROUP BY 1
)
SELECT
    p.month,
    p.printed_revenue,
    a.authoritative_revenue,
    a.missing_price_lines,
    d.all_lines_total
FROM printed_revenue p
LEFT JOIN authoritative_revenue a ON a.month = p.month
LEFT JOIN all_lines_diagnostic d ON d.month = p.month
ORDER BY p.month;
"""

with psycopg.connect(
    "host=localhost port=5432 dbname=annapurna "
    "user=annapurna password=annapurna"
) as conn:
    with conn.cursor() as cur:
        cur.execute(SQL)
        warehouse = {
            month: {
                "printed": money(printed),
                "authoritative": money(authoritative),
                "missing_prices": missing_prices,
                "all_lines": money(all_lines),
            }
            for month, printed, authoritative, missing_prices, all_lines
            in cur.fetchall()
        }

lines = []
lines.append(
    "month | finance | fact_revenue | authoritative_price | difference | classification | finance action"
)
lines.append("-" * 125)

for month in sorted(finance):
    target = finance[month]
    data = warehouse.get(month, {})
    printed = data.get("printed", Decimal("0"))
    authoritative = data.get("authoritative", Decimal("0"))
    missing_prices = data.get("missing_prices", 0)
    all_lines = data.get("all_lines", Decimal("0"))
    difference = target - printed

    if same(target, printed):
        classification = "MATCH"
        action = "No action required."

    elif month == "2024-07":
        classification = "SOURCE DATA"
        action = (
            "Take to Finance: S07 has three permanently missing July exports; "
            "Finance holds the phone-in figures."
        )

    elif missing_prices == 0 and same(target, authoritative):
        classification = "SOURCE DATA"
        action = (
            "Do not change Finance: till printed prices differ from the "
            "authoritative price-revision source."
        )

    elif same(target, all_lines):
        classification = "DEFINITION DIFFERENCE"
        action = (
            "Take to Finance: Finance appears to be using all lines, including "
            "TAX/TENDER, while the agreed revenue definition excludes them."
        )

    else:
        classification = "PIPELINE BUG / INVESTIGATE"
        action = (
            "Do not take to Finance yet: inspect loading, line-type filtering, "
            "and product/date joins first."
        )

    lines.append(
        f"{month} | {target:.2f} | {printed:.2f} | "
        f"{authoritative:.2f} | {difference:.2f} | "
        f"{classification} | {action}"
    )

report = "\n".join(lines)
(OUTPUT / "monthly_reconciliation.txt").write_text(report, encoding="utf-8")
print(report)
print("\nSaved: output(f)\\monthly_reconciliation.txt")