FROM python:3.12-slim

# Keep Python lean and unbuffered inside the container.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install the package first (leverages layer caching for dependencies).
COPY pyproject.toml README.md ./
COPY src ./src
RUN pip install --no-cache-dir .

# Bring in the example fixture so `docker run ... scan /app/examples` works.
COPY examples ./examples

# Scan results and calendars live under /data by default.
VOLUME ["/data"]
WORKDIR /data

ENTRYPOINT ["tether"]
CMD ["--help"]
