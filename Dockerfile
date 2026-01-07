# =============================================================================
# Docker Sandbox Template for GitHub Copilot CLI
# =============================================================================
# This image provides a sandboxed environment for running GitHub Copilot CLI
# similar to how docker/sandbox-templates:claude-code works for Claude Code.
#
# Usage with docker sandbox:
#   docker sandbox run --template ghcr.io/henrybravo/docker-sandbox-run-copilot copilot
#
# Or standalone:
#   docker run -it --rm -v $(pwd):/workspace ghcr.io/henrybravo/docker-sandbox-run-copilot
#
# =============================================================================

FROM ubuntu:24.04

# Copilot CLI version (passed via --build-arg or defaults to latest)
ARG COPILOT_VERSION=latest

LABEL org.opencontainers.image.title="Docker Sandbox Template for GitHub Copilot CLI"
LABEL org.opencontainers.image.description="Sandboxed environment for running GitHub Copilot CLI agent"
LABEL org.opencontainers.image.authors="Henry Bravo <henry@bravo.it>"
LABEL org.opencontainers.image.source="https://github.com/henrybravo/docker-sandbox-run-copilot"
LABEL org.opencontainers.image.version="${COPILOT_VERSION}"
LABEL org.opencontainers.image.licenses="MIT"
LABEL com.docker.sandboxes="templates"
LABEL com.docker.sandboxes.base="ubuntu:24.04"
LABEL com.docker.sandboxes.flavor="copilot-cli"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# =============================================================================
# Install system dependencies
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Essential tools
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    # Development tools
    git \
    build-essential \
    # Shell utilities
    bash \
    bash-completion \
    jq \
    ripgrep \
    tree \
    less \
    vim \
    nano \
    # Network tools
    openssh-client \
    # Process management
    sudo \
    procps \
    # Python (for various tools and MCP servers)
    python3 \
    python3-pip \
    python3-venv \
    # Go runtime (common in development)
    golang-go \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Install Node.js (LTS) - Required for Copilot CLI
# =============================================================================
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Install GitHub CLI (gh) - Useful for GitHub operations
# =============================================================================
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Install Docker CLI (for docker-in-docker scenarios)
# =============================================================================
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Create non-root user 'agent' with sudo access (matching Docker sandbox conventions)
# =============================================================================
RUN useradd -m -s /bin/bash -G sudo agent \
    && echo "agent ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/agent \
    && chmod 0440 /etc/sudoers.d/agent

# =============================================================================
# Install GitHub Copilot CLI globally
# =============================================================================
ARG COPILOT_VERSION
RUN npm install -g @github/copilot@${COPILOT_VERSION}

# =============================================================================
# Set up user environment
# =============================================================================
USER agent
WORKDIR /home/agent

# Create directories for Copilot CLI configuration and state
RUN mkdir -p /home/agent/.config/copilot \
    && mkdir -p /home/agent/.local/state/copilot \
    && mkdir -p /home/agent/.local/share/copilot

# Set XDG directories for Copilot CLI
ENV XDG_CONFIG_HOME=/home/agent/.config
ENV XDG_STATE_HOME=/home/agent/.local/state
ENV XDG_DATA_HOME=/home/agent/.local/share

# Add npm global bin to PATH
ENV PATH="/home/agent/.npm-global/bin:$PATH"
ENV NPM_CONFIG_PREFIX=/home/agent/.npm-global

# =============================================================================
# Configure shell
# =============================================================================
COPY --chown=agent:agent bashrc.sandbox /home/agent/.bashrc.sandbox
RUN echo 'source ~/.bashrc.sandbox' >> /home/agent/.bashrc

# =============================================================================
# Set up entrypoint
# =============================================================================
COPY --chown=agent:agent entrypoint.sh /home/agent/entrypoint.sh
RUN chmod +x /home/agent/entrypoint.sh

# Working directory for mounted workspaces
WORKDIR /workspace

ENTRYPOINT ["/home/agent/entrypoint.sh"]
CMD ["copilot"]
