import boto3
from botocore import UNSIGNED
from botocore.config import Config
import io
import json
from pypdf import PdfReader

def inspect_one_file():
    s3 = boto3.client('s3', config=Config(signature_version=UNSIGNED, region_name='ap-south-1'))
    
    # 1. Inspect a JSON file from SC bucket
    # I saw data-old/sc-judgments-1953-english.index.json in previous output (truncated)
    # Let's try to list specifically to get a real key
    print("--- Inspecting JSON ---")
    try:
        resp = s3.list_objects_v2(Bucket="indian-supreme-court-judgments", Prefix="data-old/", MaxKeys=1)
        if 'Contents' in resp:
            key = resp['Contents'][0]['Key']
            print(f"Downloading {key}...")
            obj = s3.get_object(Bucket="indian-supreme-court-judgments", Key=key)
            content = obj['Body'].read().decode('utf-8')
            print(f"Content Preview (first 500 chars):\n{content[:500]}")
    except Exception as e:
        print(f"Error inspecting JSON: {e}")

    # 2. Inspect a PDF from High Court bucket
    print("\n--- Inspecting PDF ---")
    try:
        # Search for a PDF
        resp = s3.list_objects_v2(Bucket="indian-high-court-judgments", Prefix="data/pdf/", MaxKeys=20) # Go deep enough
        pdf_key = None
        if 'Contents' in resp:
            for o in resp['Contents']:
                if o['Key'].endswith('.pdf'):
                    pdf_key = o['Key']
                    break
        
        if pdf_key:
            print(f"Downloading PDF {pdf_key}...")
            obj = s3.get_object(Bucket="indian-high-court-judgments", Key=pdf_key)
            pdf_stream = io.BytesIO(obj['Body'].read())
            
            reader = PdfReader(pdf_stream)
            text = ""
            for page in reader.pages:
                text += page.extract_text() + "\n"
            
            print(f"Extracted Text Preview (first 500 chars):\n{text[:500]}")
        else:
            print("No PDF found in the first few items.")

    except Exception as e:
        print(f"Error inspecting PDF: {e}")

if __name__ == "__main__":
    inspect_one_file()
