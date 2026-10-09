FROM python:3.12-slim

# Only the Python client is needed: we attach to the existing Chromium over CDP,
# so no browser binaries are downloaded.
RUN pip install --no-cache-dir playwright==1.47.0

COPY sync.py /app/sync.py
CMD ["python", "-u", "/app/sync.py"]
