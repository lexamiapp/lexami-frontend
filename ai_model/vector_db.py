import os
from dotenv import load_dotenv
from langchain_community.vectorstores import FAISS
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.document_loaders import PyPDFLoader, TextLoader, DirectoryLoader
import os

load_dotenv()

class VectorDB:
    def __init__(self, knowledge_base_path="knowledge_base", index_path="faiss_index_hf"):
        self.knowledge_base_path = knowledge_base_path
        self.index_path = index_path
        # Using Local HuggingFace Embeddings to avoid hitting Google API Rate Limits
        print("Initializing Local Embeddings (HuggingFace)...")
        self.embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")
        self.vector_store = None

    def load_or_create_index(self):
        if os.path.exists(self.index_path):
            self.vector_store = FAISS.load_local(self.index_path, self.embeddings, allow_dangerous_deserialization=True)
            print("Loaded existing FAISS index.")
        else:
            self.create_index()

    def create_index(self):
        print(f"Creating new FAISS index from {self.knowledge_base_path}...")
        loader = DirectoryLoader(self.knowledge_base_path, glob="**/*.txt", loader_cls=TextLoader)
        # You can add more loaders for PDF, etc.
        # pdf_loader = DirectoryLoader(self.knowledge_base_path, glob="**/*.pdf", loader_cls=PyPDFLoader)
        
        documents = loader.load()
        if not documents:
            print("No documents found in knowledge base. Creating an empty index.")
            # Create a dummy document if empty to avoid errors
            from langchain.schema import Document
            documents = [Document(page_content="Initial legal knowledge base.", metadata={"source": "system"})]

        text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=100)
        docs = text_splitter.split_documents(documents)
        
        self.vector_store = FAISS.from_documents(docs, self.embeddings)
        self.vector_store.save_local(self.index_path)
        print("FAISS index created and saved.")

    def similarity_search(self, query, k=3):
        if not self.vector_store:
            self.load_or_create_index()
        return self.vector_store.similarity_search(query, k=k)

if __name__ == "__main__":
    db = VectorDB()
    db.load_or_create_index()
    results = db.similarity_search("How does alimony work?")
    for res in results:
        print(f"Source: {res.metadata['source']}\nContent: {res.page_content[:100]}...\n")
