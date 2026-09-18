import boto3
from botocore.config import Config

s3 = boto3.client(
    "s3",
    endpoint_url="http://localhost:9000",
    aws_access_key_id="minioadmin",
    aws_secret_access_key="minioadmin",
    region_name="us-east-1",
    config=Config(s3={"addressing_style": "path"})
)

bucket = "annapurna-curated"

def object_stats(prefix):
    count = 0
    total_bytes = 0

    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            count += 1
            total_bytes += obj["Size"]

    return count, total_bytes

partitioned = "sales/store=S01/year=2024/month=10/"
all_sales = "sales/"

p_files, p_bytes = object_stats(partitioned)
a_files, a_bytes = object_stats(all_sales)

print("Store S01, October 2024")
print("Partitioned layout:", p_files, "files,", p_bytes, "bytes")
print("One-folder comparison:", a_files, "files,", a_bytes, "bytes")