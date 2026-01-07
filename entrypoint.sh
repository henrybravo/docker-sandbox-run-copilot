#!/bin/bash
# =============================================================================
# Entrypoint script for GitHub Copilot CLI Docker Sandbox
# =============================================================================
# This script handles:
# - Credential setup from environment variables or mounted volumes
# - Git configuration injection
# - Workspace preparation
# - Copilot CLI launch
# =============================================================================

set -e

# =============================================================================
# Color output helpers
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Git Configuration
# =============================================================================
setup_git_config() {
    # Check for git config from environment (injected by docker sandbox)
    if [ -n "$GIT_USER_NAME" ]; then
        git config --global user.name "$GIT_USER_NAME"
        success "Git user.name configured: $GIT_USER_NAME"
    fi

    if [ -n "$GIT_USER_EMAIL" ]; then
        git config --global user.email "$GIT_USER_EMAIL"
        success "Git user.email configured: $GIT_USER_EMAIL"
    fi

    # Set safe directory for mounted workspace
    if [ -d "/workspace" ]; then
        git config --global --add safe.directory /workspace
    fi
    
    # Also mark current directory as safe if different
    if [ "$(pwd)" != "/workspace" ] && [ -d "$(pwd)" ]; then
        git config --global --add safe.directory "$(pwd)"
    fi
}

# =============================================================================
# GitHub Token Setup
# =============================================================================
setup_github_token() {
    # Copilot CLI uses GITHUB_TOKEN or GH_TOKEN for authentication
    # Priority: GITHUB_TOKEN > GH_TOKEN > COPILOT_GITHUB_TOKEN
    
    if [ -n "$GITHUB_TOKEN" ]; then
        export GH_TOKEN="$GITHUB_TOKEN"
        success "Using GITHUB_TOKEN for authentication"
        return 0
    fi

    if [ -n "$GH_TOKEN" ]; then
        success "Using GH_TOKEN for authentication"
        return 0
    fi

    if [ -n "$COPILOT_GITHUB_TOKEN" ]; then
        export GITHUB_TOKEN="$COPILOT_GITHUB_TOKEN"
        export GH_TOKEN="$COPILOT_GITHUB_TOKEN"
        success "Using COPILOT_GITHUB_TOKEN for authentication"
        return 0
    fi

    # Check for mounted credentials volume (following Docker sandbox convention)
    if [ -f "/mnt/copilot-data/.github_token" ]; then
        export GITHUB_TOKEN=$(cat /mnt/copilot-data/.github_token)
        export GH_TOKEN="$GITHUB_TOKEN"
        success "Using token from mounted credentials volume"
        return 0
    fi

    # No token found - user will need to authenticate interactively
    warn "No GitHub token found. You will need to authenticate with /login"
    warn "Set GITHUB_TOKEN, GH_TOKEN, or COPILOT_GITHUB_TOKEN environment variable"
    return 0
}

# =============================================================================
# Workspace Setup
# =============================================================================
setup_workspace() {
    # If WORKSPACE_PATH is set, use it
    if [ -n "$WORKSPACE_PATH" ] && [ -d "$WORKSPACE_PATH" ]; then
        cd "$WORKSPACE_PATH"
        success "Workspace: $WORKSPACE_PATH"
        return 0
    fi

    # Default to /workspace if it exists and has content
    if [ -d "/workspace" ] && [ "$(ls -A /workspace 2>/dev/null)" ]; then
        cd /workspace
        success "Workspace: /workspace (mounted from host)"
        return 0
    fi

    # Fall back to home directory (no volume mounted)
    cd /home/agent
    warn "No workspace mounted. Using container home: /home/agent"
    info "Tip: Run with: docker sandbox run -w \$PWD copilot"
}

# =============================================================================
# SSH Agent Setup (for git operations)
# =============================================================================
setup_ssh_agent() {
    # Check for mounted SSH directory
    if [ -d "/home/agent/.ssh" ] || [ -d "/mnt/copilot-data/.ssh" ]; then
        # Start SSH agent if not running
        if [ -z "$SSH_AUTH_SOCK" ]; then
            eval "$(ssh-agent -s)" > /dev/null 2>&1
            
            # Add keys from mounted directory
            for key in /home/agent/.ssh/id_* /mnt/copilot-data/.ssh/id_*; do
                if [ -f "$key" ] && [[ ! "$key" =~ \.pub$ ]]; then
                    ssh-add "$key" 2>/dev/null && info "Added SSH key: $(basename $key)"
                fi
            done
        fi
    fi
}

# =============================================================================
# Display Welcome Banner
# =============================================================================
show_banner() {
    local workspace_path
    workspace_path=$(pwd)
    # Truncate if longer than 49 chars, add ellipsis
    if [ ${#workspace_path} -gt 49 ]; then
        workspace_path="...${workspace_path: -46}"
    fi
    # Pad to exactly 49 chars for consistent box width (62 inner - 13 prefix)
    workspace_path=$(printf '%-49s' "$workspace_path")

    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}     ${GREEN}GitHub Copilot CLI - Docker Sandbox${NC}                      ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  Running in isolated container environment                   ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  Workspace: ${workspace_path}${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# =============================================================================
# Main Entry Point
# =============================================================================
main() {
    info "Initializing GitHub Copilot CLI sandbox..."
    
    # Run setup functions
    setup_git_config
    setup_github_token
    setup_workspace
    setup_ssh_agent
    
    # Show welcome banner
    show_banner
    
    # If no arguments provided, start copilot interactively
    if [ $# -eq 0 ]; then
        info "Starting Copilot CLI..."
        exec copilot
    fi

    # If first argument is 'copilot', pass remaining args to copilot
    if [ "$1" = "copilot" ]; then
        shift
        exec copilot "$@"
    fi
    
    # If first argument is 'bash' or 'sh', start a shell
    if [ "$1" = "bash" ] || [ "$1" = "sh" ]; then
        exec "$@"
    fi
    
    # Otherwise, treat all arguments as a prompt to copilot
    # This allows: docker run ... "fix the bug in main.py"
    exec copilot --prompt "$*"
}

# Run main with all arguments
main "$@"
