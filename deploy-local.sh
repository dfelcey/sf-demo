#!/bin/bash
# Simple local deployment script - no GitHub Actions needed

set +e  # Don't exit on error

# Default values
VERBOSE=false
INSTANCE_URL="https://login.salesforce.com"
ORG_ALIAS=""

# Parse command line arguments
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [ORG_ALIAS] [INSTANCE_URL]

Deploy Salesforce project directly using local CLI.

Arguments:
  ORG_ALIAS       Org alias for authentication (required if not set via -a)
  INSTANCE_URL    Salesforce instance URL (default: https://login.salesforce.com)

Options:
  -v, --verbose              Enable verbose output
  -h, --help                 Show this help message

Examples:
  $0 -v production-org                  # Verbose mode with org alias
  $0 my-org https://test.salesforce.com # Alias + instance URL
  $0 https://test.salesforce.com my-org # Instance URL + alias

EOF
}

# Parse arguments
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Set positional arguments (accept alias-only, url-only, or both)
if [ ${#POSITIONAL_ARGS[@]} -eq 1 ]; then
    if [[ "${POSITIONAL_ARGS[0]}" == *"://"* ]]; then
        INSTANCE_URL="${POSITIONAL_ARGS[0]}"
    else
        ORG_ALIAS="${POSITIONAL_ARGS[0]}"
    fi
elif [ ${#POSITIONAL_ARGS[@]} -ge 2 ]; then
    if [[ "${POSITIONAL_ARGS[0]}" == *"://"* ]]; then
        INSTANCE_URL="${POSITIONAL_ARGS[0]}"
        ORG_ALIAS="${POSITIONAL_ARGS[1]}"
    else
        ORG_ALIAS="${POSITIONAL_ARGS[0]}"
        INSTANCE_URL="${POSITIONAL_ARGS[1]}"
    fi
fi

echo "=========================================="
echo "🚀 Local Salesforce Deployment"
echo "=========================================="
echo ""
echo "This will deploy directly to Salesforce using your local CLI."
echo "No GitHub Actions needed!"
echo ""
if [ "$VERBOSE" = true ]; then
    echo "Verbose mode: enabled"
fi
echo "Instance URL: $INSTANCE_URL"
echo "Org Alias: ${ORG_ALIAS:-"(not set)"}"
echo ""

# Check if Salesforce CLI is installed
if ! command -v sf &> /dev/null; then
    echo "❌ Salesforce CLI (sf) is not installed!"
    echo ""
    
    # Check for Node.js/npm
    if ! command -v npm &> /dev/null; then
        echo "❌ npm is also not installed!"
        echo ""
        echo "Node.js and npm are required prerequisites."
        echo ""
        read -p "Do you want to install Node.js and Salesforce CLI now? (Y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            # Try to install Node.js
            if [[ "$OSTYPE" == "darwin"* ]]; then
                if command -v brew &> /dev/null; then
                    echo "Installing Node.js via Homebrew..."
                    brew install node || {
                        echo "❌ Failed to install Node.js. Please install manually: https://nodejs.org/"
                        exit 1
                    }
                else
                    echo "❌ Homebrew not found. Please install Node.js manually: https://nodejs.org/"
                    exit 1
                fi
            elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                echo "Installing Node.js..."
                curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
                sudo apt-get install -y nodejs || {
                    echo "❌ Failed to install Node.js. Please install manually: https://nodejs.org/"
                    exit 1
                }
            else
                echo "❌ Unsupported OS. Please install Node.js manually: https://nodejs.org/"
                exit 1
            fi
        else
            exit 1
        fi
    fi
    
    echo "Installing Salesforce CLI..."
    npm install -g @salesforce/cli@latest || {
        echo "❌ Failed to install Salesforce CLI"
        echo "Try: sudo npm install -g @salesforce/cli@latest"
        exit 1
    }
    
    # Refresh PATH
    export PATH="$PATH:$(npm config get prefix)/bin"
    
    if ! command -v sf &> /dev/null; then
        echo "❌ CLI installed but not in PATH. Try: export PATH=\"\$PATH:$(npm config get prefix)/bin\""
        exit 1
    fi
fi

SF_VERSION=$(sf --version 2>&1)
echo "✅ Salesforce CLI found: $SF_VERSION"

# Check for updates if verbose
if [ "$VERBOSE" = true ]; then
    echo ""
    echo "Checking for CLI updates..."
    LATEST=$(npm view @salesforce/cli version 2>/dev/null || echo "")
    if [ -n "$LATEST" ]; then
        CURRENT=$(echo "$SF_VERSION" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [ "$CURRENT" != "$LATEST" ]; then
            echo "⚠️  Update available: $CURRENT -> $LATEST"
            read -p "Update now? (y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                npm install -g @salesforce/cli@latest && echo "✅ Updated to: $(sf --version 2>&1)"
            fi
        else
            echo "✅ CLI is up to date: $CURRENT"
        fi
    fi
fi
echo ""

# Require org alias
if [ -z "$ORG_ALIAS" ]; then
    echo "❌ Org alias is required"
    echo ""
    echo "Usage: $0 -v <alias> [instance_url]"
    exit 1
fi

# Check if already authenticated
echo "Checking for authenticated Salesforce org..."
ORG_LIST=$(sf org list --json 2>/dev/null)
EXISTING_ORG=$(echo "$ORG_LIST" | grep -o "\"alias\":\"${ORG_ALIAS}\"" || echo "")

if [ -z "$EXISTING_ORG" ]; then
    echo "No authenticated org found with alias: $ORG_ALIAS"
    echo ""
    echo "Registering and authenticating this alias..."
    echo ""
    echo "This will open your browser to log in to Salesforce."
    echo ""
    sf org login web --alias "$ORG_ALIAS" --instance-url "$INSTANCE_URL" || {
        echo "❌ Salesforce login failed"
        exit 1
    }
    
    echo ""
    echo "✅ Successfully authenticated to Salesforce!"
else
    echo "✅ Found authenticated org: $ORG_ALIAS"
    echo ""
fi

# Optionally set default org

echo ""
# Verify org is authenticated
sf org display --target-org "$ORG_ALIAS" --json > /dev/null 2>&1 || {
    echo "❌ Target org '$ORG_ALIAS' is not authenticated"
    echo "Available orgs:"
    sf org list || true
    exit 1
}

# Show org info
ORG_INFO=$(sf org display --target-org "$ORG_ALIAS" --json 2>/dev/null)
ORG_USERNAME=$(echo "$ORG_INFO" | jq -r '.result.username // "unknown"' 2>/dev/null || echo "unknown")
echo "Target org: $ORG_USERNAME"
echo ""

echo "=========================================="
echo "📦 Deploying to Salesforce"
echo "=========================================="
echo ""

# Check what we're deploying
if [ ! -d "force-app" ]; then
    echo "❌ force-app directory not found!"
    echo "Current directory: $(pwd)"
    exit 1
fi

echo "Deploying from force-app directory..."
echo ""

# Check for Agent Script files (AiAuthoringBundle) and provide info
if [ -d "force-app/main/default/aiAuthoringBundles" ]; then
    echo "📝 Found Agent Script files (AiAuthoringBundle) to deploy"
    echo ""
    echo "Note: After deployment, you may need to publish authoring bundles:"
    echo "  sf agent publish --target-org $ORG_ALIAS"
    echo ""
fi

# Deploy
sf project deploy start --source-dir force-app --target-org "$ORG_ALIAS" --wait 10 || {
    echo ""
    echo "❌ Deployment failed"
    echo ""
    echo "Check the error messages above for details."
    exit 1
}

echo ""
echo "✅ Deployment completed successfully!"
echo ""

# If Agent Script files were deployed, remind about publishing
if [ -d "force-app/main/default/aiAuthoringBundles" ]; then
    echo "📝 Agent Script files deployed. To activate agents, publish authoring bundles:"
    echo "  sf agent publish --target-org $ORG_ALIAS"
    echo ""
fi

echo "Org: $ORG_USERNAME"
echo "View in Salesforce: $(echo "$ORG_INFO" | jq -r '.result.instanceUrl // ""' 2>/dev/null || echo "")"

