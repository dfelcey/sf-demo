#!/bin/bash
# Simple local deployment script - no GitHub Actions needed

set +e  # Don't exit on error

# Default values
VERBOSE=false
INSTANCE_URL="https://login.salesforce.com"
ORG_ALIAS="deploy-target"
PACKAGES=""  # Comma-separated package IDs or version IDs
PACKAGES_FILE=".packages"  # File containing package IDs (one per line)
PACKAGE_VERSION_FILE=".package-version"  # File containing package version ID for this project
USE_PACKAGE=true  # Prefer package installation over direct deployment

# Parse command line arguments
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [INSTANCE_URL] [ORG_ALIAS]

Deploy Salesforce project directly using local CLI.

Arguments:
  INSTANCE_URL    Salesforce instance URL (default: https://login.salesforce.com)
  ORG_ALIAS       Org alias for authentication (default: deploy-target)

Options:
  -v, --verbose              Enable verbose output
  -p, --packages PACKAGES    Comma-separated package IDs to install (04t... or 0Ho...)
  --packages-file FILE       File containing package IDs (one per line, default: .packages)
  --package-version ID       Package version ID to install (04t...) - overrides .package-version file
  --no-package               Skip package installation, deploy metadata directly
  -h, --help                 Show this help message

Examples:
  $0                                    # Use defaults (prefers package if .package-version exists)
  $0 -v                                 # Verbose mode with defaults
  $0 --package-version 04tXXXXXXXXXXXXX # Install specific package version
  $0 --no-package                       # Deploy metadata directly (skip package)
  $0 -p 04t000000000000                # Install dependency packages before deploying
  $0 -p 04t000000000000,04t000000000001 # Install multiple dependency packages
  $0 --packages-file .packages          # Install dependency packages from file
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
        -p|--packages)
            PACKAGES="$2"
            shift 2
            ;;
        --packages-file)
            PACKAGES_FILE="$2"
            shift 2
            ;;
        --package-version)
            PACKAGE_VERSION="$2"
            shift 2
            ;;
        --no-package)
            USE_PACKAGE=false
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
echo "📦 Installing Packages"
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
echo "Target org: $ORG_USERNAME"
echo ""

# Function to install a package
install_package() {
    local PACKAGE_ID="$1"
    if [ -z "$PACKAGE_ID" ]; then
        return 1
    fi
    
    # Remove whitespace
    PACKAGE_ID=$(echo "$PACKAGE_ID" | xargs)
    
    # Skip empty lines and comments
    if [ -z "$PACKAGE_ID" ] || [[ "$PACKAGE_ID" =~ ^# ]]; then
        return 0
    fi
    
    echo "Installing package: $PACKAGE_ID"
    
    # Check if package is already installed
    INSTALLED_CHECK=$(sf package installed list --target-org "$ORG_ALIAS" --json 2>/dev/null)
    if [ $? -eq 0 ] && command -v jq &> /dev/null; then
        IS_INSTALLED=$(echo "$INSTALLED_CHECK" | jq -r ".result[] | select(.SubscriberPackageVersionId == \"$PACKAGE_ID\" or .SubscriberPackageId == \"$PACKAGE_ID\") | .SubscriberPackageVersionId" 2>/dev/null)
        if [ -n "$IS_INSTALLED" ]; then
            echo "  ⏭️  Package already installed, skipping..."
            return 0
        fi
    fi
    
    # Install the package
    if [ "$VERBOSE" = true ]; then
        sf package install --package "$PACKAGE_ID" --target-org "$ORG_ALIAS" --wait 10 --no-prompt || {
            echo "  ❌ Failed to install package: $PACKAGE_ID"
            return 1
        }
    else
        sf package install --package "$PACKAGE_ID" --target-org "$ORG_ALIAS" --wait 10 --no-prompt > /dev/null 2>&1 || {
            echo "  ❌ Failed to install package: $PACKAGE_ID"
            return 1
        }
    fi
    
    echo "  ✅ Package installed successfully"
    return 0
}

# Collect packages to install
PACKAGES_TO_INSTALL=()

# Read packages from command line argument
if [ -n "$PACKAGES" ]; then
    IFS=',' read -ra PACKAGE_ARRAY <<< "$PACKAGES"
    for pkg in "${PACKAGE_ARRAY[@]}"; do
        PACKAGES_TO_INSTALL+=("$pkg")
    done
fi

# Read packages from file if it exists
if [ -f "$PACKAGES_FILE" ]; then
    echo "Reading packages from: $PACKAGES_FILE"
    while IFS= read -r line || [ -n "$line" ]; do
        PACKAGES_TO_INSTALL+=("$line")
    done < "$PACKAGES_FILE"
fi

# Install packages if any are specified
if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
    echo "Found ${#PACKAGES_TO_INSTALL[@]} package(s) to install"
    echo ""
    
    FAILED_PACKAGES=()
    for pkg in "${PACKAGES_TO_INSTALL[@]}"; do
        if ! install_package "$pkg"; then
            FAILED_PACKAGES+=("$pkg")
        fi
        echo ""
    done
    
    if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
        echo "⚠️  Warning: ${#FAILED_PACKAGES[@]} package(s) failed to install:"
        for pkg in "${FAILED_PACKAGES[@]}"; do
            echo "  - $pkg"
        done
        echo ""
        read -p "Continue with deployment anyway? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Deployment cancelled"
            exit 1
        fi
    else
        echo "✅ All packages installed successfully!"
        echo ""
    fi
else
    echo "No packages specified for installation"
    echo "Use -p to specify packages or create a .packages file"
    echo ""
fi

echo "=========================================="
echo "📦 Deploying to Salesforce"
echo "=========================================="
echo ""

# Check for package version file if not explicitly provided
if [ -z "$PACKAGE_VERSION" ] && [ "$USE_PACKAGE" = true ] && [ -f "$PACKAGE_VERSION_FILE" ]; then
    PACKAGE_VERSION=$(grep -v '^#' "$PACKAGE_VERSION_FILE" | grep -v '^$' | head -1 | xargs)
    if [ -n "$PACKAGE_VERSION" ]; then
        echo "Found package version in $PACKAGE_VERSION_FILE: $PACKAGE_VERSION"
        echo ""
    fi
fi

# Deploy via package installation (preferred method)
if [ -n "$PACKAGE_VERSION" ] && [ "$USE_PACKAGE" = true ]; then
    echo "🚀 Installing package version: $PACKAGE_VERSION"
    echo ""
    echo "Package installation is faster and more reliable than direct metadata deployment."
    echo ""
    
    # Check if package is already installed
    INSTALLED_CHECK=$(sf package installed list --target-org "$ORG_ALIAS" --json 2>/dev/null)
    if [ $? -eq 0 ] && command -v jq &> /dev/null; then
        IS_INSTALLED=$(echo "$INSTALLED_CHECK" | jq -r ".result[] | select(.SubscriberPackageVersionId == \"$PACKAGE_VERSION\") | .SubscriberPackageVersionId" 2>/dev/null)
        if [ -n "$IS_INSTALLED" ]; then
            echo "✅ Package version already installed"
            echo ""
            echo "To upgrade to a new version, update $PACKAGE_VERSION_FILE with the new version ID"
            echo "or use: $0 --package-version <new-version-id>"
            echo ""
            echo "Org: $ORG_USERNAME"
            echo "View in Salesforce: $(echo "$ORG_INFO" | jq -r '.result.instanceUrl // ""' 2>/dev/null || echo "")"
            exit 0
        fi
    fi
    
    # Install the package
    if [ "$VERBOSE" = true ]; then
        sf package install --package "$PACKAGE_VERSION" --target-org "$ORG_ALIAS" --wait 10 --no-prompt || {
            echo ""
            echo "❌ Package installation failed"
            echo ""
            echo "Falling back to direct metadata deployment..."
            echo ""
            USE_PACKAGE=false
        }
    else
        sf package install --package "$PACKAGE_VERSION" --target-org "$ORG_ALIAS" --wait 10 --no-prompt 2>&1 | grep -v "^$" || {
            echo ""
            echo "❌ Package installation failed"
            echo ""
            echo "Falling back to direct metadata deployment..."
            echo ""
            USE_PACKAGE=false
        }
    fi
    
    if [ "$USE_PACKAGE" = true ]; then
        echo ""
        echo "✅ Package installed successfully!"
        echo ""
        echo "Org: $ORG_USERNAME"
        echo "View in Salesforce: $(echo "$ORG_INFO" | jq -r '.result.instanceUrl // ""' 2>/dev/null || echo "")"
        exit 0
    fi
fi

# Fallback to direct metadata deployment
if [ "$USE_PACKAGE" = false ] || [ -z "$PACKAGE_VERSION" ]; then
    if [ "$USE_PACKAGE" = false ]; then
        echo "Deploying metadata directly (--no-package flag specified)"
    else
        echo "No package version configured, deploying metadata directly"
        echo ""
        echo "💡 Tip: For faster deployments, create a package and use package installation:"
        echo "  1. Create package: ./create-package.sh -a devhub-org"
        echo "  2. Save version ID to .package-version file"
        echo "  3. Run: ./deploy-local.sh (will use package automatically)"
    fi
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
fi

