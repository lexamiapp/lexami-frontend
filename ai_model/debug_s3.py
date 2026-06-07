import boto3
from botocore import UNSIGNED
from botocore.config import Config

def explore_bucket(bucket_name):
    s3 = boto3.client('s3', config=Config(signature_version=UNSIGNED, region_name='ap-south-1'))
    print(f"\n--- Exploring {bucket_name} ---")
    
    # List top level
    try:
        response = s3.list_objects_v2(Bucket=bucket_name, Delimiter='/', MaxKeys=20)
        print("Top Level Prefixes (Folders):")
        if 'CommonPrefixes' in response:
            for p in response['CommonPrefixes']:
                print(f" 📁 {p['Prefix']}")
                
        print("Top Level Files:")
        if 'Contents' in response:
            for obj in response['Contents']:
                print(f" 📄 {obj['Key']}")
                
        # If there is a 'data-old/' or 'data/', lets look inside
        prefixes_to_check = ['data/', 'data-old/', 'csv/']
        for prefix in prefixes_to_check:
             # Check if this prefix actually exists in the top level list we just got
             exists = False
             if 'CommonPrefixes' in response:
                 for p in response['CommonPrefixes']:
                     if p['Prefix'] == prefix:
                         exists = True
             
             if exists:
                 print(f"\nListing contents of {prefix}...")
                 resp2 = s3.list_objects_v2(Bucket=bucket_name, Prefix=prefix, MaxKeys=5)
                 if 'Contents' in resp2:
                     for obj in resp2['Contents']:
                         print(f" - {obj['Key']}")

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    explore_bucket("indian-supreme-court-judgments")
    explore_bucket("indian-high-court-judgments")
