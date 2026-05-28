FROM python:3.12-slim

WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpcap-dev gcc && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN python assets/sprites/generate_sprites.py

EXPOSE 8765
CMD ["python", "main.py", "--simulation", "--web"]
