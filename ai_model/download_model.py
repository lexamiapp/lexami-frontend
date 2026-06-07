from langchain_huggingface import HuggingFaceEmbeddings
import os

def download_model():
    print("Starting model download for baking into image...")
    # This triggers the download to the cache directory defined by HF_HOME
    HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")
    print("Model 'all-MiniLM-L6-v2' downloaded successfully.")

if __name__ == "__main__":
    download_model()
