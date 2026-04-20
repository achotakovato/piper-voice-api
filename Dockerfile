FROM python:3.10-slim-bullseye

WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive

# Системные зависимости + ФИКС: добавлен unzip
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget ca-certificates libsndfile1 ffmpeg unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/* && \
    pip install --upgrade pip --no-cache-dir

# Python зависимости
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Модели (Piper + Vosk)
RUN mkdir -p /app/models && \
    wget -q https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/ru/ru_RU/dmitri/medium/ru_RU-dmitri-medium.onnx -P /app/models && \
    wget -q https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/ru/ru_RU/dmitri/medium/ru_RU-dmitri-medium.onnx.json -P /app/models && \
    wget -q https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip -P /tmp && \
    unzip -q /tmp/vosk-model-small-ru-0.22.zip -d /app/models && \
    rm -rf /tmp/*.zip

# Код
COPY . .

ENV PYTHONUNBUFFERED=1 OMP_NUM_THREADS=1
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
