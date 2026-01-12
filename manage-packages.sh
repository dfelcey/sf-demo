#!/bin/bash
# Salesforce Package Management Script
# Handles package installation, uninstallation, and other org management tasks

set +e  # Don't exit on error initially

# Default values
VERBOSE=false
ORG_ALIAS="deploy-target"
ACTION="install"
PACKAGE_ID=""
PACKAGE_VERSION_ID=""
WAIT_TIME=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] ACTION [PACKAGE_ID]

Salesforce Package Management Script

Actions:
  install              Install a package (requires PACKAGE_ID or PACKAGE_VERSION_ID)
  uninstall           Uninstall a package (requires PACKAGE_ID)
  list-installed      List all installed packages in the org
  list-available      List available packages (requires package registry)
  upgrade             Upgrade an installed package (requires PACKAGE_VERSION_ID)
  create-scratch      Create a new scratch org
  delete-scratch      Delete a scratch org
  open-org            Open the org in browser
  run-tests           Run Apex tests
  validate            Validate deployment without deploying

Options:
  -a, --alias ALIAS          Org alias (default: deploy-target)
  -p, --package-id ID        Package ID (04t... for managed, 0Ho... for unlocked)
  -v, --version-id ID        Package Version ID (04t...)
  -w, --wait MINUTES         Wait time in minutes (default: 10)
  -t, --test-level LEVEL     Test level for deployment (NoTestRun, RunSpecifiedTests, RunLocalTests, RunAllTestsInOrg)
  -c, --class-names NAMES    Comma-separated test class names (for RunSpecifiedTests)
  -f, --force                Force operation (skip confirmation)
  --verbose                  Enable verbose output
  -h, --help                 Show this help message

Examples:
  # Install a managed package
  $0 install -p 04t000000000000

  # Install an unlocked package by version ID
  $0 install -v 04t000000000000AAA

  # List installed packages
  $0 list-installed

  # Uninstall a package
  $0 uninstall -p 04t000000000000

  # Upgrade a package
  $0 upgrade -v 04t000000000000AAA

  # Create a scratch org
  $0 create-scratch -a my-scratch

  # Run tests
  $0 run-tests -t RunLocalTests

  # Validate deployment
  $0 validate

EOF
}

# Check if Salesforce CLI is installed
check_cli() {
    if ! command -v sf &> /dev/null; then
        log_error "Salesforce CLI (sf) is not installed!"
        echo ""
        echo "Please install it:"
        echo "  npm install -g @salesforce/cli"
        echo ""
        echo "Or visit: https://developer.salesforce.com/tools/salesforcecli"
        exit 1
    fi
    log_debug "Salesforce CLI found: $(sf --version)"
}

# Verify org is authenticated
verify_org() {
    log_info "Verifying org authentication..."
    ORG_CHECK=$(sf org display --target-org "$ORG_ALIAS" --json 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_error "Org '$ORG_ALIAS' is not authenticated"
        echo ""
        echo "Available orgs:"
        sf org list || true
        echo ""
        echo "To authenticate, run:"
        echo "  sf org login web --alias $ORG_ALIAS"
        exit 1
    fi
    
    ORG_USERNAME=$(echo "$ORG_CHECK" | jq -r '.result.username // "unknown"' 2>/dev/null || echo "unknown")
    ORG_ID=$(echo "$ORG_CHECK" | jq -r '.result.id // "unknown"' 2>/dev/null || echo "unknown")
    log_success "Org verified: $ORG_USERNAME"
    log_debug "Org ID: $ORG_ID"
}

# Install package
install_package() {
    if [ -z "$PACKAGE_ID" ] && [ -z "$PACKAGE_VERSION_ID" ]; then
        log_error "Package ID or Version ID required for installation"
        echo ""
        echo "Use -p for Package ID (04t...) or -v for Version ID (04t...)"
        exit 1
    fi
    
    verify_org
    
    log_info "Installing package..."
    
    if [ -n "$PACKAGE_VERSION_ID" ]; then
        log_info "Installing package version: $PACKAGE_VERSION_ID"
        INSTALL_CMD="sf package install --package $PACKAGE_VERSION_ID --target-org $ORG_ALIAS --wait $WAIT_TIME --no-prompt"
    else
        log_info "Installing package: $PACKAGE_ID"
        INSTALL_CMD="sf package install --package $PACKAGE_ID --target-org $ORG_ALIAS --wait $WAIT_TIME --no-prompt"
    fi
    
    log_debug "Command: $INSTALL_CMD"
    
    if [ "$FORCE" != true ]; then
        echo ""
        read -p "Continue with installation? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
    fi
    
    $INSTALL_CMD || {
        log_error "Package installation failed"
        exit 1
    }
    
    log_success "Package installed successfully!"
}

# Uninstall package
uninstall_package() {
    if [ -z "$PACKAGE_ID" ]; then
        log_error "Package ID required for uninstallation"
        echo ""
        echo "Use -p to specify Package ID (04t...)"
        exit 1
    fi
    
    verify_org
    
    log_info "Uninstalling package: $PACKAGE_ID"
    
    if [ "$FORCE" != true ]; then
        echo ""
        log_warn "Uninstalling a package cannot be undone!"
        read -p "Continue with uninstallation? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Uninstallation cancelled"
            exit 0
        fi
    fi
    
    sf package uninstall --package "$PACKAGE_ID" --target-org "$ORG_ALIAS" --wait $WAIT_TIME --no-prompt || {
        log_error "Package uninstallation failed"
        exit 1
    }
    
    log_success "Package uninstalled successfully!"
}

# List installed packages
list_installed() {
    verify_org
    
    log_info "Fetching installed packages..."
    
    INSTALLED=$(sf package installed list --target-org "$ORG_ALIAS" --json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to fetch installed packages"
        exit 1
    fi
    
    echo ""
    echo "=========================================="
    echo "📦 Installed Packages"
    echo "=========================================="
    echo ""
    
    # Try to parse with jq, fallback to raw output
    if command -v jq &> /dev/null; then
        PACKAGE_COUNT=$(echo "$INSTALLED" | jq '.result | length' 2>/dev/null || echo "0")
        if [ "$PACKAGE_COUNT" = "0" ] || [ -z "$PACKAGE_COUNT" ]; then
            echo "No packages installed."
        else
            echo "$INSTALLED" | jq -r '.result[] | "\(.SubscriberPackageName) (\(.SubscriberPackageVersionId))\n  Namespace: \(.NamespacePrefix // "none")\n  Version: \(.MajorVersion).\(.MinorVersion).\(.PatchVersion).\(.BuildNumber)\n  Installed: \(.InstalledDate)\n"' 2>/dev/null || echo "$INSTALLED"
        fi
    else
        echo "$INSTALLED"
    fi
}

# Upgrade package
upgrade_package() {
    if [ -z "$PACKAGE_VERSION_ID" ]; then
        log_error "Package Version ID required for upgrade"
        echo ""
        echo "Use -v to specify Version ID (04t...)"
        exit 1
    fi
    
    verify_org
    
    log_info "Upgrading package to version: $PACKAGE_VERSION_ID"
    
    if [ "$FORCE" != true ]; then
        echo ""
        read -p "Continue with upgrade? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Upgrade cancelled"
            exit 0
        fi
    fi
    
    sf package install --package "$PACKAGE_VERSION_ID" --target-org "$ORG_ALIAS" --wait $WAIT_TIME --upgrade-only --no-prompt || {
        log_error "Package upgrade failed"
        exit 1
    }
    
    log_success "Package upgraded successfully!"
}

# Create scratch org
create_scratch() {
    log_info "Creating scratch org..."
    
    if [ ! -f "config/project-scratch-def.json" ]; then
        log_error "project-scratch-def.json not found!"
        echo ""
        echo "Create a scratch org definition file at: config/project-scratch-def.json"
        exit 1
    fi
    
    log_info "Using scratch org definition: config/project-scratch-def.json"
    
    sf org create scratch --definition-file config/project-scratch-def.json --alias "$ORG_ALIAS" --duration-days 7 --set-default || {
        log_error "Failed to create scratch org"
        exit 1
    }
    
    log_success "Scratch org created: $ORG_ALIAS"
    
    # Show org info
    ORG_INFO=$(sf org display --target-org "$ORG_ALIAS" --json 2>/dev/null)
    ORG_USERNAME=$(echo "$ORG_INFO" | jq -r '.result.username // "unknown"' 2>/dev/null || echo "unknown")
    ORG_URL=$(echo "$ORG_INFO" | jq -r '.result.instanceUrl // ""' 2>/dev/null || echo "")
    
    echo ""
    echo "Org Username: $ORG_USERNAME"
    echo "Org URL: $ORG_URL"
}

# Delete scratch org
delete_scratch() {
    verify_org
    
    log_warn "This will permanently delete the scratch org: $ORG_ALIAS"
    
    if [ "$FORCE" != true ]; then
        read -p "Continue? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deletion cancelled"
            exit 0
        fi
    fi
    
    sf org delete scratch --target-org "$ORG_ALIAS" --no-prompt || {
        log_error "Failed to delete scratch org"
        exit 1
    }
    
    log_success "Scratch org deleted: $ORG_ALIAS"
}

# Open org in browser
open_org() {
    verify_org
    
    log_info "Opening org in browser..."
    
    sf org open --target-org "$ORG_ALIAS" || {
        log_error "Failed to open org"
        exit 1
    }
}

# Run tests
run_tests() {
    verify_org
    
    TEST_LEVEL="${TEST_LEVEL:-RunLocalTests}"
    
    log_info "Running Apex tests..."
    log_info "Test Level: $TEST_LEVEL"
    
    if [ "$TEST_LEVEL" = "RunSpecifiedTests" ] && [ -n "$TEST_CLASS_NAMES" ]; then
        log_info "Test Classes: $TEST_CLASS_NAMES"
        TEST_CMD="sf apex run test --test-level $TEST_LEVEL --class-names $TEST_CLASS_NAMES --target-org $ORG_ALIAS --wait $WAIT_TIME --result-format human --code-coverage --output-dir test-results"
    else
        TEST_CMD="sf apex run test --test-level $TEST_LEVEL --target-org $ORG_ALIAS --wait $WAIT_TIME --result-format human --code-coverage --output-dir test-results"
    fi
    
    log_debug "Command: $TEST_CMD"
    
    $TEST_CMD || {
        log_error "Test execution failed"
        exit 1
    }
    
    log_success "Tests completed!"
    log_info "Results saved to: test-results/"
}

# Validate deployment
validate_deployment() {
    verify_org
    
    if [ ! -d "force-app" ]; then
        log_error "force-app directory not found!"
        exit 1
    fi
    
    log_info "Validating deployment (dry-run)..."
    
    sf project deploy start --source-dir force-app --target-org "$ORG_ALIAS" --dry-run --wait $WAIT_TIME || {
        log_error "Validation failed"
        exit 1
    }
    
    log_success "Validation completed successfully!"
    log_info "No errors found. Ready to deploy."
}

# Parse arguments
POSITIONAL_ARGS=()
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--alias)
            ORG_ALIAS="$2"
            shift 2
            ;;
        -p|--package-id)
            PACKAGE_ID="$2"
            shift 2
            ;;
        -v|--version-id)
            PACKAGE_VERSION_ID="$2"
            shift 2
            ;;
        -w|--wait)
            WAIT_TIME="$2"
            shift 2
            ;;
        -t|--test-level)
            TEST_LEVEL="$2"
            shift 2
            ;;
        -c|--class-names)
            TEST_CLASS_NAMES="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        install|uninstall|list-installed|list-available|upgrade|create-scratch|delete-scratch|open-org|run-tests|validate)
            ACTION="$1"
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            # If it looks like a package ID, use it
            if [[ "$1" =~ ^04t[0-9A-Za-z]{15}$ ]] || [[ "$1" =~ ^0Ho[0-9A-Za-z]{15}$ ]]; then
                if [ -z "$PACKAGE_ID" ]; then
                    PACKAGE_ID="$1"
                else
                    PACKAGE_VERSION_ID="$1"
                fi
            else
                POSITIONAL_ARGS+=("$1")
            fi
            shift
            ;;
    esac
done

# Main execution
echo "=========================================="
echo "📦 Salesforce Package Management"
echo "=========================================="
echo ""

check_cli

case "$ACTION" in
    install)
        install_package
        ;;
    uninstall)
        uninstall_package
        ;;
    list-installed)
        list_installed
        ;;
    list-available)
        log_warn "List available packages not yet implemented"
        echo "Use: sf package version list"
        ;;
    upgrade)
        upgrade_package
        ;;
    create-scratch)
        create_scratch
        ;;
    delete-scratch)
        delete_scratch
        ;;
    open-org)
        open_org
        ;;
    run-tests)
        run_tests
        ;;
    validate)
        validate_deployment
        ;;
    *)
        log_error "Unknown action: $ACTION"
        echo ""
        show_usage
        exit 1
        ;;
esac

