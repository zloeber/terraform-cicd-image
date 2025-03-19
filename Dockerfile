# Start from Python base image
FROM python:3.13.2-bookworm AS builder

# Install dependencies and create a non-root user
RUN \
  apt-get update \
  && apt-get install -y curl unzip git \
  && rm -rf /var/lib/apt/lists/* \
  && useradd -m -s /bin/bash appuser

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV MISE_INSTALL_PATH="/usr/local/bin/mise"

RUN curl -fsSL https://mise.jdx.dev/install.sh | sh

# Switch to appuser for safer installations
USER appuser
WORKDIR /home/appuser

ENV TF_PLUGIN_CACHE_DIR="/home/appuser/.terraform.d/plugin-cache"

COPY --chown=appuser:appuser mise.toml .
COPY --chown=appuser:appuser scripts ./scripts
COPY --chown=appuser:appuser pyproject.toml .
COPY --chown=appuser:appuser uv.lock .
COPY --chown=appuser:appuser .python-version .
COPY --chown=appuser:appuser config ./config
COPY policy /opt/policy

# Install Terraform versions using mise and set latest version as default
RUN \
  mise trust \
  && mise install -y \
  && mkdir -p $TF_PLUGIN_CACHE_DIR \
  && mise exec uv@latest -- uv sync \
  && mise exec uv@latest -- uv run ./scripts/install-providers.py \
  && rm -rf ./config

# Final lightweight image
FROM python:3.13.2-bookworm

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install necessary dependencies and create a non-root user
RUN apt-get update && apt-get install -y unzip git \
  && rm -rf /var/lib/apt/lists/* \
  && useradd -m -s /bin/bash appuser

# Copy mise and appuser from builder stage
COPY --from=builder /home/appuser /home/appuser
COPY --from=builder /usr/local/bin/mise /usr/local/bin/mise

# Ensure mise shims are in the PATH for appuser
ENV PATH="/home/appuser/.local/share/mise/shims:$PATH"

# Set up Terraform provider cache directory (customizable)
ENV TF_PLUGIN_CACHE_DIR="/home/appuser/.terraform.d/plugin-cache"

# Set working directory
WORKDIR /home/appuser

# Switch to non-root user
USER appuser

# Default command
CMD ["terraform", "version"]
