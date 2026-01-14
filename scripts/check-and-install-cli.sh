#!/bin/bash
# Shared function to check and install Salesforce CLI prerequisites and CLI itself
# This can be sourced by other scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

# Check and install Node.js/npm
check_nodejs() {
    local AUTO_INSTALL=${1:-false}
    
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        NODE_VERSION=$(node --version)
        NPM_VERSION=$(npm --version)
        log_success "Node.js found: $NODE_VERSION"
        log_success "npm found: $NPM_VERSION"
        return 0
    fi
    
    log_warn "Node.js or npm is not installed"
    
    if [ "$AUTO_INSTALL" = true ]; then
        log_info "Attempting to install Node.js..."
        OS=$(detect_os)
        
        if [ "$OS" = "macos" ]; then
            if command -v brew &> /dev/null; then
                log_info "Installing Node.js via Homebrew..."
                brew install node || {
                    log_error "Failed to install Node.js via Homebrew"
                    return 1
                }
            else
                log_error "Homebrew not found. Please install Node.js manually:"
                echo "  brew install node"
                echo "  Or download from: https://nodejs.org/"
                return 1
            fi
        elif [ "$OS" = "linux" ]; then
            log_info "Installing Node.js via NodeSource repository..."
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - || {
                log_error "Failed to add NodeSource repository"
                return 1
            }
            sudo apt-get install -y nodejs || {
                log_error "Failed to install Node.js"
                return 1
            }
        else
            log_error "Unsupported OS. Please install Node.js manually from: https://nodejs.org/"
            return 1
        fi
        
        # Verify installation
        if command -v node &> /dev/null && command -v npm &> /dev/null; then
            log_success "Node.js installed: $(node --version)"
            log_success "npm installed: $(npm --version)"
            return 0
        else
            log_error "Node.js installation completed but not found in PATH"
            return 1
        fi
    else
        echo ""
        read -p "Do you want to install Node.js now? (Y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log_error "Node.js is required. Please install it manually:"
            echo "  macOS: brew install node"
            echo "  Linux: See https://nodejs.org/en/download/"
            echo "  Or visit: https://nodejs.org/"
            return 1
        fi
        
        return $(check_nodejs true)
    fi
}

# Get latest Salesforce CLI version from npm
get_latest_cli_version() {
    npm view @salesforce/cli version 2>/dev/null || echo ""
}

# Compare version strings (returns 0 if v1 >= v2, 1 otherwise)
compare_versions() {
    local v1="$1"
    local v2="$2"
    
    # Extract version numbers (handle formats like "@salesforce/cli/2.108.6")
    v1=$(echo "$v1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    v2=$(echo "$v2" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    if [ -z "$v1" ] || [ -z "$v2" ]; then
        return 1
    fi
    
    # Compare major.minor.patch
    local IFS='.'
    read -ra v1_parts <<< "$v1"
    read -ra v2_parts <<< "$v2"
    
    for i in {0..2}; do
        if [ "${v1_parts[$i]:-0}" -gt "${v2_parts[$i]:-0}" ]; then
            return 0
        elif [ "${v1_parts[$i]:-0}" -lt "${v2_parts[$i]:-0}" ]; then
            return 1
        fi
    done
    
    return 0  # Versions are equal
}

# Check and install/update Salesforce CLI
check_salesforce_cli() {
    local AUTO_INSTALL=${1:-false}
    local AUTO_UPDATE=${2:-false}
    
    # First ensure Node.js/npm is available
    if ! check_nodejs "$AUTO_INSTALL"; then
        return 1
    fi
    
    # Check if CLI is installed
    if command -v sf &> /dev/null; then
        SF_VERSION=$(sf --version 2>&1)
        log_success "Salesforce CLI found: $SF_VERSION"
        
        # Check if update is needed
        if [ "$AUTO_UPDATE" = true ]; then
            log_info "Checking for CLI updates..."
            LATEST_VERSION=$(get_latest_cli_version)
            
            if [ -n "$LATEST_VERSION" ]; then
                CURRENT_VERSION=$(echo "$SF_VERSION" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
                
                if compare_versions "$LATEST_VERSION" "$CURRENT_VERSION"; then
                    if [ "$LATEST_VERSION" != "$CURRENT_VERSION" ]; then
                        log_warn "CLI update available: $CURRENT_VERSION -> $LATEST_VERSION"
                        log_info "Updating Salesforce CLI..."
                        npm install -g @salesforce/cli@latest || {
                            log_error "Failed to update Salesforce CLI"
                            return 1
                        }
                        log_success "Salesforce CLI updated to: $(sf --version 2>&1)"
                    else
                        log_success "Salesforce CLI is up to date: $CURRENT_VERSION"
                    fi
                fi
            fi
        fi
        
        return 0
    fi
    
    # CLI not installed
    log_warn "Salesforce CLI (sf) is not installed!"
    
    if [ "$AUTO_INSTALL" = true ]; then
        log_info "Installing latest Salesforce CLI..."
        npm install -g @salesforce/cli@latest || {
            log_error "Failed to install Salesforce CLI"
            echo ""
            echo "Troubleshooting:"
            echo "  - Ensure npm has write permissions: npm config get prefix"
            echo "  - Try with sudo: sudo npm install -g @salesforce/cli@latest"
            return 1
        }
        
        # Verify installation
        if command -v sf &> /dev/null; then
            SF_VERSION=$(sf --version 2>&1)
            log_success "Salesforce CLI installed: $SF_VERSION"
            return 0
        else
            # May need to refresh PATH
            export PATH="$PATH:$(npm config get prefix)/bin"
            if command -v sf &> /dev/null; then
                SF_VERSION=$(sf --version 2>&1)
                log_success "Salesforce CLI installed: $SF_VERSION"
                log_warn "Note: You may need to restart your terminal or run: export PATH=\"\$PATH:$(npm config get prefix)/bin\""
                return 0
            else
                log_error "Salesforce CLI installation completed but 'sf' command not found"
                echo "Try running: export PATH=\"\$PATH:$(npm config get prefix)/bin\""
                return 1
            fi
        fi
    else
        echo ""
        read -p "Do you want to install Salesforce CLI now? (Y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log_error "Salesforce CLI is required. Please install it manually:"
            echo "  npm install -g @salesforce/cli@latest"
            echo "  Or visit: https://developer.salesforce.com/tools/salesforcecli"
            return 1
        fi
        
        return $(check_salesforce_cli true "$AUTO_UPDATE")
    fi
}

# Main function - check and install/update everything
ensure_cli_ready() {
    local AUTO_INSTALL=${1:-false}
    local AUTO_UPDATE=${2:-false}
    
    log_info "Checking Salesforce CLI prerequisites..."
    
    if check_salesforce_cli "$AUTO_INSTALL" "$AUTO_UPDATE"; then
        # Ensure PATH includes npm global bin
        NPM_PREFIX=$(npm config get prefix 2>/dev/null)
        if [ -n "$NPM_PREFIX" ] && [[ ":$PATH:" != *":$NPM_PREFIX/bin:"* ]]; then
            export PATH="$PATH:$NPM_PREFIX/bin"
        fi
        
        SF_VERSION=$(sf --version 2>&1)
        log_success "Salesforce CLI is ready: $SF_VERSION"
        return 0
    else
        return 1
    fi
}

