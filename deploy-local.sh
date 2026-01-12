#!/bin/bash
# Simple local deployment script - no GitHub Actions needed

set +e  # Don't exit on error

# Default values
VERBOSE=false
INSTANCE_URL="https://login.salesforce.com"
ORG_ALIAS="deploy-target"

# Parse command line arguments
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [INSTANCE_URL] [ORG_ALIAS]

Deploy Salesforce project directly using local CLI.

Arguments:
  INSTANCE_URL    Salesforce instance URL (default: https://login.salesforce.com)
  ORG_ALIAS       Org alias for authentication (default: deploy-target)

Options:
  -v, --verbose   Enable verbose output
  -h, --help      Show this help message

Examples:
  $0                                    # Use defaults
  $0 -v                                 # Verbose mode with defaults
  $0 https://test.salesforce.com        # Specify instance URL
  $0 -v production-org                  # Verbose mode with org alias
  $0 https://login.salesforce.com prod  # Specify both

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

# Set positional arguments
if [ ${#POSITIONAL_ARGS[@]} -gt 0 ]; then
    INSTANCE_URL="${POSITIONAL_ARGS[0]}"
fi
if [ ${#POSITIONAL_ARGS[@]} -gt 1 ]; then
    ORG_ALIAS="${POSITIONAL_ARGS[1]}"
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
echo "Org Alias: $ORG_ALIAS"
echo ""

# Check if Salesforce CLI is installed
if ! command -v sf &> /dev/null; then
    echo "❌ Salesforce CLI (sf) is not installed!"
    echo ""
    echo "Please install it:"
    echo "  npm install -g @salesforce/cli"
    echo ""
    echo "Or visit: https://developer.salesforce.com/tools/salesforcecli"
    exit 1
fi

echo "✅ Salesforce CLI found: $(sf --version)"
echo ""

# Check if already authenticated
echo "Checking for authenticated Salesforce org..."
ORG_LIST=$(sf org list --json 2>/dev/null)
EXISTING_ORG=$(echo "$ORG_LIST" | grep -o "\"alias\":\"${ORG_ALIAS}\"" || echo "")

if [ -z "$EXISTING_ORG" ]; then
    echo "No authenticated org found with alias: $ORG_ALIAS"
    echo ""
    echo "This will open your browser to log in to Salesforce."
    echo ""
    read -p "Press Enter to continue with Salesforce login..."
    
    sf org login web --alias "$ORG_ALIAS" --instance-url "$INSTANCE_URL" || {
        echo "❌ Salesforce login failed"
        exit 1
    }
    
    echo ""
    echo "✅ Successfully authenticated to Salesforce!"
else
    echo "✅ Found authenticated org: $ORG_ALIAS"
    echo ""
    read -p "Do you want to login to a different org? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sf org login web --alias "$ORG_ALIAS" --instance-url "$INSTANCE_URL" || {
            echo "❌ Salesforce login failed"
            exit 1
        }
        echo ""
        echo "✅ Successfully authenticated to Salesforce!"
    fi
fi

echo ""
echo "=========================================="
echo "📦 Deploying to Salesforce"
echo "=========================================="
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
echo "Deploying to org: $ORG_USERNAME"
echo ""

# Check what we're deploying
if [ ! -d "force-app" ]; then
    echo "❌ force-app directory not found!"
    echo "Current directory: $(pwd)"
    exit 1
fi

echo "Deploying from force-app directory..."
echo ""

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
echo "Org: $ORG_USERNAME"
echo "View in Salesforce: $(echo "$ORG_INFO" | jq -r '.result.instanceUrl // ""' 2>/dev/null || echo "")"

