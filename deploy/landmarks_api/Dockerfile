FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    LANDMARKS_DIR=/app/data/local_landmarks \
    DEFAULT_LIMIT=50 \
    MAX_LIMIT=5000

WORKDIR /app

COPY deploy/landmarks_api/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY deploy/landmarks_api/app /app/app
COPY assets/data/local_landmarks /app/data/local_landmarks

EXPOSE 8080

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
