FROM python:3.10-slim

WORKDIR /app

# Системные зависимости
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget ca-certificates libsndfile1 ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --upgrade pip

# Python зависимости
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Создаём директорию для моделей
RUN mkdir -p /app/models

# Скачиваем модели ПРЯМО В ДОКЕР (чтобы не качать при каждом старте)
RUN wget -q https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/ru/ru_RU/dmitri/medium/ru_RU-dmitri-medium.onnx -P /app/models && \
    wget -q https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/ru/ru_RU/dmitri/medium/ru_RU-dmitri-medium.onnx.json -P /app/models && \
    wget -q https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip -P /tmp && \
    unzip -q /tmp/vosk-model-small-ru-0.22.zip -d /app/models && \
    mv /app/models/vosk-model-small-ru-0.22 /app/models/vosk-model-small-ru-0.22_temp && \
    mv /app/models/vosk-model-small-ru-0.22_temp /app/models/vosk-model-small-ru-0.22 && \
    rm -rf /tmp/*.zip

# Копируем код
COPY . .

# ENV для оптимизации
ENV PYTHONUNBUFFERED=1
ENV OMP_NUM_THREADS=1

EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]