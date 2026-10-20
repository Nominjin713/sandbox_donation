FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8080 \
    DJANGO_DEBUG=false

WORKDIR /app
COPY requirements.txt ./
RUN pip install -r requirements.txt \
    && useradd --create-home --uid 10001 donation

COPY manage.py start_server.py ./
COPY config ./config
COPY accounts ./accounts
COPY events ./events

USER donation
EXPOSE 8080
CMD ["python", "start_server.py"]
