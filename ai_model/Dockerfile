# Use an official Python runtime as a parent image
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
# Set HF_HOME to a directory inside the container so the model is persisted in the image
ENV HF_HOME=/app/hf_cache

# Set the working directory in the container
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy the requirements file into the container at /app
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code into the container at /app
COPY . .

# Run the download script to bake the model into the image
RUN python download_model.py

# Expose the port the app runs on
EXPOSE 8080

# Command to run the application using Gunicorn for production routing
# We bind to 0.0.0.0:$PORT (Cloud Run injects the PORT env var)
CMD exec gunicorn --bind :${PORT:-8080} --workers 1 --worker-class uvicorn.workers.UvicornWorker --threads 8 --timeout 0 main:app
