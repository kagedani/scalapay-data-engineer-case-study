FROM python:3.12-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Poetry
RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:$PATH"

# Set work directory
WORKDIR /app

# Copy Poetry configuration files
COPY pyproject.toml poetry.toml poetry.lock ./

# Configure Poetry and install dependencies
RUN poetry config virtualenvs.create false \
    && poetry install --with dev

# Copy the rest of the application
COPY . .

# Make entrypoint script executable
RUN chmod +x /app/entrypoint.sh

# Set the entrypoint and default command
ENTRYPOINT ["/bin/bash", "/app/entrypoint.sh"]
CMD ["/bin/bash"]
