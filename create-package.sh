#!/bin/bash
# Script to create a Salesforce package with Agentforce assets

set +e

# Default values
PACKAGE_NAME="Agentforce Assets"
PACKAGE_TYPE="Unlocked"  # Unlocked or Managed
ORG_ALIAS=""
DESCRIPTION="Agentforce agent assets including GenAI Functions, Plugins, Flows, and supporting Apex classes"
VERSION="1.0.0"

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

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Create a Salesforce package with Agentforce assets.

Options:
  -a, --alias ALIAS          Dev Hub org alias (required)
  -n, --name NAME            Package name (default: "Agentforce Assets")
  -t, --type TYPE            Package type: Unlocked or Managed (default: Unlocked)
  -d, --description DESC     Package description
  -v, --version VERSION      Package version (default: 1.0.0)
  -h, --help                 Show this help message

Examples:
  # Create unlocked package
  $0 -a devhub-org

  # Create managed package
  $0 -a devhub-org -t Managed

  # Create package with custom name
  $0 -a devhub-org -n "My Agentforce Package" -v 2.0.0

EOF
}

# Check if Salesforce CLI is installed
check_cli() {
    if ! command -v sf &> /dev/null; then
        log_error "Salesforce CLI (sf) is not installed!"
        echo ""
        echo "Please install it:"
        echo "  npm install -g @salesforce/cli"
        exit 1
    fi
}

# Verify Dev Hub org
verify_devhub() {
    if [ -z "$ORG_ALIAS" ]; then
        log_error "Dev Hub org alias is required"
        echo ""
        echo "Use -a to specify a Dev Hub org alias"
        echo ""
        echo "To see available orgs:"
        echo "  sf org list"
        exit 1
    fi
    
    log_info "Verifying Dev Hub org..."
    ORG_CHECK=$(sf org display --target-org "$ORG_ALIAS" --json 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_error "Org '$ORG_ALIAS' is not authenticated"
        echo ""
        echo "To authenticate, run:"
        echo "  sf org login web --alias $ORG_ALIAS --instance-url https://login.salesforce.com"
        exit 1
    fi
    
    # Check if org is a Dev Hub
    IS_DEVHUB=$(echo "$ORG_CHECK" | jq -r '.result.isDevHub // false' 2>/dev/null || echo "false")
    if [ "$IS_DEVHUB" != "true" ]; then
        log_warn "Org '$ORG_ALIAS' may not be a Dev Hub"
        echo ""
        echo "To enable Dev Hub:"
        echo "1. Go to Setup → Dev Hub"
        echo "2. Enable Dev Hub"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    ORG_USERNAME=$(echo "$ORG_CHECK" | jq -r '.result.username // "unknown"' 2>/dev/null || echo "unknown")
    log_success "Dev Hub org verified: $ORG_USERNAME"
}

# Create package
create_package() {
    log_info "Creating $PACKAGE_TYPE package: $PACKAGE_NAME"
    
    # Convert package name to API name (no spaces, alphanumeric + underscore)
    PACKAGE_API_NAME=$(echo "$PACKAGE_NAME" | sed 's/[^a-zA-Z0-9_]/_/g' | sed 's/__*/_/g')
    
    # Check if package already exists
    EXISTING_PKG=$(sf package list --target-dev-hub "$ORG_ALIAS" --json 2>/dev/null | jq -r ".result[] | select(.Name == \"$PACKAGE_NAME\" or .Id != null) | .Id" 2>/dev/null | head -1)
    
    if [ -n "$EXISTING_PKG" ]; then
        log_warn "Package '$PACKAGE_NAME' already exists (ID: $EXISTING_PKG)"
        echo ""
        read -p "Create a new version instead? (Y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log_info "Using existing package: $EXISTING_PKG"
            PACKAGE_ID="$EXISTING_PKG"
            create_package_version
            return
        fi
    fi
    
    # Create new package
    if [ "$PACKAGE_TYPE" = "Managed" ]; then
        CREATE_CMD="sf package create --name \"$PACKAGE_NAME\" --description \"$DESCRIPTION\" --package-type Managed --target-dev-hub $ORG_ALIAS --no-namespace"
    else
        CREATE_CMD="sf package create --name \"$PACKAGE_NAME\" --description \"$DESCRIPTION\" --package-type Unlocked --target-dev-hub $ORG_ALIAS"
    fi
    
    log_info "Command: $CREATE_CMD"
    
    CREATE_OUTPUT=$(eval $CREATE_CMD 2>&1)
    CREATE_EXIT=$?
    
    if [ $CREATE_EXIT -ne 0 ]; then
        log_error "Failed to create package"
        echo "$CREATE_OUTPUT"
        exit 1
    fi
    
    # Extract package ID from output
    PACKAGE_ID=$(echo "$CREATE_OUTPUT" | grep -oP 'Id: \K[0-9a-zA-Z]{18}' || echo "")
    
    if [ -z "$PACKAGE_ID" ]; then
        # Try JSON output
        PACKAGE_ID=$(echo "$CREATE_OUTPUT" | jq -r '.result.Id // empty' 2>/dev/null || echo "")
    fi
    
    if [ -z "$PACKAGE_ID" ]; then
        log_error "Could not extract package ID from output"
        echo "$CREATE_OUTPUT"
        exit 1
    fi
    
    log_success "Package created: $PACKAGE_ID"
    echo ""
    echo "Package Details:"
    echo "  Name: $PACKAGE_NAME"
    echo "  Type: $PACKAGE_TYPE"
    echo "  ID: $PACKAGE_ID"
    echo ""
    
    create_package_version
}

# Create package version
create_package_version() {
    log_info "Creating package version..."
    
    # Verify force-app exists
    if [ ! -d "force-app" ]; then
        log_error "force-app directory not found!"
        exit 1
    fi
    
    # Build version command
    VERSION_CMD="sf package version create --package \"$PACKAGE_NAME\" --target-dev-hub $ORG_ALIAS --wait 10 --code-coverage --installation-key-bypass"
    
    if [ "$PACKAGE_TYPE" = "Managed" ]; then
        VERSION_CMD="$VERSION_CMD --version-number $VERSION"
    fi
    
    log_info "Command: $VERSION_CMD"
    echo ""
    log_info "This may take several minutes..."
    echo ""
    
    VERSION_OUTPUT=$(eval $VERSION_CMD 2>&1)
    VERSION_EXIT=$?
    
    if [ $VERSION_EXIT -ne 0 ]; then
        log_error "Failed to create package version"
        echo "$VERSION_OUTPUT"
        exit 1
    fi
    
    # Extract version ID
    VERSION_ID=$(echo "$VERSION_OUTPUT" | grep -oP 'Package2VersionId: \K[0-9a-zA-Z]{18}' || echo "")
    
    if [ -z "$VERSION_ID" ]; then
        VERSION_ID=$(echo "$VERSION_OUTPUT" | jq -r '.result.Package2VersionId // empty' 2>/dev/null || echo "")
    fi
    
    if [ -z "$VERSION_ID" ]; then
        log_error "Could not extract version ID"
        echo "$VERSION_OUTPUT"
        exit 1
    fi
    
    log_success "Package version created: $VERSION_ID"
    echo ""
    echo "=========================================="
    echo "📦 Package Created Successfully!"
    echo "=========================================="
    echo ""
    echo "Package Name: $PACKAGE_NAME"
    echo "Package Type: $PACKAGE_TYPE"
    echo "Version: $VERSION"
    echo "Package ID: $PACKAGE_ID"
    echo "Version ID: $VERSION_ID"
    echo ""
    echo "To install this package in another org:"
    echo "  sf package install --package $VERSION_ID --target-org <org-alias>"
    echo ""
    echo "To list package versions:"
    echo "  sf package version list --target-dev-hub $ORG_ALIAS"
    echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--alias)
            ORG_ALIAS="$2"
            shift 2
            ;;
        -n|--name)
            PACKAGE_NAME="$2"
            shift 2
            ;;
        -t|--type)
            PACKAGE_TYPE="$2"
            shift 2
            ;;
        -d|--description)
            DESCRIPTION="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$ORG_ALIAS" ]; then
                ORG_ALIAS="$1"
            else
                log_error "Unexpected argument: $1"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Main execution
echo "=========================================="
echo "📦 Create Salesforce Package"
echo "=========================================="
echo ""

check_cli

if [ -z "$ORG_ALIAS" ]; then
    log_error "Dev Hub org alias is required"
    echo ""
    show_usage
    exit 1
fi

verify_devhub

echo ""
log_info "Package Configuration:"
echo "  Name: $PACKAGE_NAME"
echo "  Type: $PACKAGE_TYPE"
echo "  Description: $DESCRIPTION"
echo "  Version: $VERSION"
echo ""

read -p "Continue with package creation? (Y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Nn]$ ]]; then
    log_info "Package creation cancelled"
    exit 0
fi

create_package

