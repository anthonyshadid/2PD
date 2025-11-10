# Dockerfile
FROM python:3.11-slim

# Keep Python output unbuffered; avoid interactive apt prompts
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

# Install OpenSCAD (CLI) and clean up apt cache
RUN apt-get update && \
    apt-get install -y --no-install-recommends openscad ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# App setup
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

# Render will provide $PORT; default to 10000 locally
ENV PORT=10000
EXPOSE 10000

# Start Flask via Gunicorn; change app:app if your module or variable differs
CMD gunicorn -w 2 -b 0.0.0.0:$PORT app:app
