# Multi-stage build for Python application
FROM uhub.service.ucloud.cn/base-images/python:3.10-slim as builder

# Set build arguments
ARG APP_NAME=wudi
ARG APP_VERSION=latest
ARG GIT_COMMIT=unknown

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set work directory
WORKDIR /app

# Copy dependency files
COPY pyproject.toml uv.lock ./

# Install uv for faster Python package management
RUN pip install uv

# Set uv index to a domestic mirror for faster installation
ENV UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple \
    UV_HTTP_TIMEOUT=300 \
    UV_RETRIES=3 \
    UV_CONCURRENT_DOWNLOADS=1

# Install dependencies using uv with retry mechanism
RUN for i in 1 2 3; do \
        uv sync --frozen --no-cache && break || \
        (echo "Attempt $i failed, retrying in 5 seconds..." && sleep 5); \
    done && \
    uv pip list

# Production stage
FROM uhub.service.ucloud.cn/base-images/python:3.10-slim as production

# Set build arguments
ARG APP_NAME=wudi
ARG APP_VERSION=latest
ARG GIT_COMMIT=unknown

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    APP_NAME=${APP_NAME} \
    APP_VERSION=${APP_VERSION} \
    GIT_COMMIT=${GIT_COMMIT}

# Set uv configuration for production
ENV UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple \
    UV_HTTP_TIMEOUT=300 \
    UV_RETRIES=3 \
    UV_CONCURRENT_DOWNLOADS=1

# Install runtime dependencies and uv
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/* && \
    pip install uv

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set work directory
WORKDIR /app

# Copy virtual environment from builder stage
COPY --from=builder /app/.venv /app/.venv

# Copy application code (exclude unnecessary files)
COPY main.py config.py middleware.py ./
COPY templates/ ./templates/
COPY pyproject.toml uv.lock ./

# Ensure dependencies are properly installed in production
RUN uv sync --frozen --no-cache --no-dev

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Add virtual environment to PATH
ENV PATH="/app/.venv/bin:$PATH"

# Add labels for better container management
LABEL org.opencontainers.image.title="${APP_NAME}" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.created="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
      org.opencontainers.image.description="Python web application built with FastAPI"

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the application
CMD ["/app/.venv/bin/python", "main.py"]
