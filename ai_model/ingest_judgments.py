import firebase_admin
from firebase_admin import credentials, firestore
import boto3
from botocore import UNSIGNED
from botocore.config import Config
from pypdf import PdfReader
import io
import os
import re

# --- Configuration ---
# Use the same collection name as your AppConstants
COLLECTION_NAME = "landmark_judgments" 

# Keywords to filter relevant Family Law cases
KEYWORDS = [
    "divorce", "alimony", "custody", "maintenance", 
    "dowry", "domestic violence", "section 125", 
    "hindu marriage act", "special marriage act", "family court"
]

# Max number of new documents to ingest in one run
MAX_DOCS_PER_RUN = 50

# --- Firebase Setup ---
# Assumes you have a serviceAccountKey.json in the same folder or parent folder
cred_path = "./serviceAccountKey.json"
if not os.path.exists(cred_path):
    cred_path = "../serviceAccountKey.json"

if os.path.exists(cred_path):
    if not firebase_admin._apps:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("✅ Firebase initialized.")
else:
    print("❌ serviceAccountKey.json not found! Cannot sync to Firestore.")
    exit(1)

# --- S3 Setup ---
# Using the Open NyAI bucket if available, or fallback to general Indian law buckets
# Note: Many public buckets are erratic. We try a known responsive one.
BUCKETS = [
    {
        "name": "indian-supreme-court-judgments",
        "prefix": "2023/" # Focus on recent judgments first
    },
    {
        "name": "indian-high-court-judgments",
        "prefix": "data/"
    }
]

def get_s3_client():
    return boto3.client('s3', config=Config(signature_version=UNSIGNED, region_name='ap-south-1'))

def extract_text_from_pdf(pdf_bytes):
    try:
        reader = PdfReader(io.BytesIO(pdf_bytes))
        text = ""
        for page in reader.pages:
            result = page.extract_text()
            if result:
                text += result + "\n"
        return text
    except Exception:
        return ""

def clean_text(text):
    # Remove excessive whitespace
    text = re.sub(r'\s+', ' ', text)
    return text.strip()

def summarize_text(text, max_chars=2000):
    # Basic truncation. Ideally, use an LLM to generate a real summary.
    # But for search, the first 2000 chars often contain the headnotes.
    return text[:max_chars] + "..."

def document_exists(filename):
    # Check if a document with this 'source_file' already exists
    docs = db.collection(COLLECTION_NAME).where("source_file", "==", filename).limit(1).get()
    return len(docs) > 0

def ingest_data():
    s3 = get_s3_client()
    saved_count = 0
    
    print(f"🚀 Starting ingestion. limit: {MAX_DOCS_PER_RUN} new docs.")

    for bucket_info in BUCKETS:
        if saved_count >= MAX_DOCS_PER_RUN:
            break
            
        bucket_name = bucket_info["name"]
        prefix = bucket_info["prefix"]
        
        print(f"🔍 Scanning {bucket_name}...")
        
        try:
            paginator = s3.get_paginator('list_objects_v2')
            pages = paginator.paginate(Bucket=bucket_name, Prefix=prefix, PaginationConfig={'MaxItems': 500})
            
            for page in pages:
                if 'Contents' not in page:
                    continue
                    
                for obj in page['Contents']:
                    if saved_count >= MAX_DOCS_PER_RUN:
                        break

                    key = obj['Key']
                    
                    # 1. Check if we already processed this
                    unique_id = f"{bucket_name}_{key.replace('/', '_')}"
                    if document_exists(unique_id):
                        print(f"  ⏭️  Skipping existing: {key}")
                        continue

                    # 2. Filter file type
                    if not key.lower().endswith('.pdf'):
                        continue
                        
                    try:
                        # 3. Download & Extract
                        # print(f"  ⬇️  Downloading {key}...")
                        response = s3.get_object(Bucket=bucket_name, Key=key)
                        body = response['Body'].read()
                        
                        full_text = extract_text_from_pdf(body)
                        if len(full_text) < 500: # Skip empty/scanned-image PDFs
                            continue
                            
                        # 4. Keyword Check
                        full_text_lower = full_text.lower()
                        if any(k in full_text_lower for k in KEYWORDS):
                            
                            # 5. Prepare Firestore Document
                            doc_data = {
                                "title": key.split('/')[-1].replace('.pdf', '').replace('_', ' '),
                                "source_bucket": bucket_name,
                                "source_file": unique_id,
                                "summary": summarize_text(clean_text(full_text)), # Field for Vector Search
                                "full_text_url": f"s3://{bucket_name}/{key}", # Reference only
                                "keywords": [k for k in KEYWORDS if k in full_text_lower],
                                "created_at": firestore.SERVER_TIMESTAMP,
                                "year": 2023 # Placeholder, ideally parse from filename
                            }
                            
                            # 6. Upload
                            db.collection(COLLECTION_NAME).document(unique_id).set(doc_data)
                            print(f"  ✅ Uploaded: {doc_data['title']}")
                            saved_count += 1
                        
                    except Exception as e:
                        print(f"  ⚠️ Error processing {key}: {e}")
                        
        except Exception as e:
            print(f"❌ Error accessing bucket {bucket_name}: {e}")

    print(f"\n🏁 Ingestion Complete. {saved_count} new documents synced to Firestore.")
    print("ℹ️  The 'Vector Search with Firestore' extension will now automatically generate embeddings.")

if __name__ == "__main__":
    ingest_data()
