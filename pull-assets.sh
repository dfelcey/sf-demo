#!/bin/bash
# Salesforce Asset Retrieval Script
# Connects to an org and pulls specific metadata/assets

set +e  # Don't exit on error initially

# Default values
VERBOSE=false
ORG_ALIAS=""
INSTANCE_URL="https://login.salesforce.com"
METADATA_TYPES=""  # Comma-separated metadata types
METADATA_FILE=""    # File containing metadata to retrieve
OUTPUT_DIR="force-app"  # Default output directory
MANIFEST_FILE=""    # Use manifest file
WAIT_TIME=10
ADD_NEW_ORG=false   # Flag to add a new org

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
Usage: $0 [OPTIONS]

Retrieve specific metadata/assets from a Salesforce org.

Options:
  -a, --alias ALIAS          Org alias (required if not default)
  -i, --instance-url URL     Salesforce instance URL (default: https://login.salesforce.com)
  -t, --metadata-types TYPES Comma-separated metadata types (e.g., CustomObject,ApexClass)
  -f, --metadata-file FILE   File containing metadata to retrieve (one per line)
  -m, --manifest FILE        Use manifest file (package.xml)
  -o, --output-dir DIR       Output directory (default: force-app)
  -w, --wait MINUTES         Wait time in minutes (default: 10)
  --add-org                  Add/authenticate a new org (will prompt for alias if not provided)
  --new-org                  Alias for --add-org
  --list-orgs                List all authenticated orgs and exit
  --verbose                  Enable verbose output
  -h, --help                 Show this help message

Metadata Types Examples:
  CustomObject              Custom Objects
  CustomField               Custom Fields
  ApexClass                 Apex Classes
  ApexTrigger               Apex Triggers
  Profile                   Profiles
  PermissionSet             Permission Sets
  Flow                      Flows
  LightningComponentBundle  Lightning Components
  CustomTab                 Custom Tabs
  CustomApplication         Custom Applications

Examples:
  # Add a new org
  $0 --add-org -a my-org

  # Add a new org and pull metadata
  $0 --add-org -a my-org -t CustomObject,ApexClass

  # Pull specific metadata types from existing org
  $0 -a my-org -t CustomObject,ApexClass

  # Pull using manifest file
  $0 -a my-org -m manifest/package.xml

  # Pull specific objects from file
  $0 -a my-org -f objects.txt

  # Pull to custom directory
  $0 -a my-org -t CustomObject -o retrieved-metadata

  # List available orgs and metadata
  $0 --list-orgs
  $0 --list-metadata-types

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

# List available orgs
list_orgs() {
    check_cli
    echo "=========================================="
    echo "🔗 Available Salesforce Orgs"
    echo "=========================================="
    echo ""
    
    ORG_LIST=$(sf org list --json 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$ORG_LIST" ]; then
        log_warn "No authenticated orgs found"
        echo ""
        echo "To authenticate an org, run:"
        echo "  sf org login web --alias my-org"
        return
    fi
    
    if command -v jq &> /dev/null; then
        echo "$ORG_LIST" | jq -r '.result.nonScratchOrgs[]? | "\(.alias // "unnamed") - \(.username) - \(.instanceUrl)"' 2>/dev/null
        echo "$ORG_LIST" | jq -r '.result.scratchOrgs[]? | "\(.alias // "unnamed") - \(.username) - \(.instanceUrl) (Scratch)"' 2>/dev/null
    else
        sf org list
    fi
    echo ""
}

# List available metadata types
list_metadata_types() {
    check_cli
    
    if [ -z "$ORG_ALIAS" ]; then
        log_error "Org alias required to list metadata types"
        echo ""
        echo "Usage: $0 --list-metadata-types -a ORG_ALIAS"
        exit 1
    fi
    
    verify_org
    
    echo "=========================================="
    echo "📋 Available Metadata Types"
    echo "=========================================="
    echo ""
    
    log_info "Fetching metadata types from org..."
    sf project list metadata-types --target-org "$ORG_ALIAS" || {
        log_error "Failed to list metadata types"
        exit 1
    }
    echo ""
}

# Verify org is authenticated
verify_org() {
    if [ -z "$ORG_ALIAS" ]; then
        log_error "Org alias is required"
        echo ""
        echo "Use -a to specify an org alias, or run:"
        echo "  sf org login web --alias my-org"
        echo ""
        echo "To see available orgs:"
        echo "  $0 --list-orgs"
        exit 1
    fi
    
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
    ORG_URL=$(echo "$ORG_CHECK" | jq -r '.result.instanceUrl // ""' 2>/dev/null || echo "")
    
    log_success "Org verified: $ORG_USERNAME"
    log_debug "Org ID: $ORG_ID"
    log_debug "Instance URL: $ORG_URL"
}

# Add/authenticate a new org
add_new_org() {
    if [ -z "$ORG_ALIAS" ]; then
        echo ""
        read -p "Enter a name for this org (alias): " ORG_ALIAS
        if [ -z "$ORG_ALIAS" ]; then
            log_error "Org alias is required"
            exit 1
        fi
    fi
    
    # Check if org alias already exists
    ORG_LIST=$(sf org list --json 2>/dev/null)
    EXISTING_ORG=$(echo "$ORG_LIST" | grep -o "\"alias\":\"${ORG_ALIAS}\"" || echo "")
    
    if [ -n "$EXISTING_ORG" ]; then
        log_warn "Org alias '$ORG_ALIAS' already exists"
        echo ""
        read -p "Do you want to re-authenticate this org? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Using existing org: $ORG_ALIAS"
            return 0
        fi
    fi
    
    log_info "Adding new org: $ORG_ALIAS"
    echo ""
    echo "Instance URL: $INSTANCE_URL"
    echo ""
    echo "This will open your browser to log in to Salesforce."
    echo ""
    read -p "Press Enter to continue with Salesforce login..."
    
    sf org login web --alias "$ORG_ALIAS" --instance-url "$INSTANCE_URL" || {
        log_error "Salesforce login failed"
        exit 1
    }
    
    log_success "Successfully authenticated new org: $ORG_ALIAS"
    
    # Show org info
    ORG_INFO=$(sf org display --target-org "$ORG_ALIAS" --json 2>/dev/null)
    ORG_USERNAME=$(echo "$ORG_INFO" | jq -r '.result.username // "unknown"' 2>/dev/null || echo "unknown")
    ORG_URL=$(echo "$ORG_INFO" | jq -r '.result.instanceUrl // ""' 2>/dev/null || echo "")
    
    echo ""
    echo "Org Details:"
    echo "  Alias: $ORG_ALIAS"
    echo "  Username: $ORG_USERNAME"
    echo "  Instance URL: $ORG_URL"
    echo ""
}

# Authenticate to org if needed
authenticate_org() {
    ORG_LIST=$(sf org list --json 2>/dev/null)
    EXISTING_ORG=$(echo "$ORG_LIST" | grep -o "\"alias\":\"${ORG_ALIAS}\"" || echo "")
    
    if [ -z "$EXISTING_ORG" ]; then
        log_info "Org '$ORG_ALIAS' not found."
        echo ""
        read -p "Do you want to authenticate this org now? (Y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            log_info "Authenticating org..."
            echo ""
            echo "This will open your browser to log in to Salesforce."
            echo ""
            read -p "Press Enter to continue with Salesforce login..."
            
            sf org login web --alias "$ORG_ALIAS" --instance-url "$INSTANCE_URL" || {
                log_error "Salesforce login failed"
                exit 1
            }
            
            log_success "Successfully authenticated to Salesforce!"
        else
            log_error "Org authentication cancelled"
            exit 1
        fi
    else
        log_info "Using existing authenticated org: $ORG_ALIAS"
    fi
}

# Retrieve using metadata types
retrieve_by_types() {
    log_info "Retrieving metadata by types..."
    
    # Create temporary manifest file
    TEMP_MANIFEST=$(mktemp)
    cat > "$TEMP_MANIFEST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
EOF
    
    IFS=',' read -ra TYPE_ARRAY <<< "$METADATA_TYPES"
    for type in "${TYPE_ARRAY[@]}"; do
        type=$(echo "$type" | xargs)  # Trim whitespace
        if [ -n "$type" ]; then
            echo "    <types>" >> "$TEMP_MANIFEST"
            echo "        <members>*</members>" >> "$TEMP_MANIFEST"
            echo "        <name>$type</name>" >> "$TEMP_MANIFEST"
            echo "    </types>" >> "$TEMP_MANIFEST"
            log_info "  Adding metadata type: $type"
        fi
    done
    
    cat >> "$TEMP_MANIFEST" << EOF
    <version>60.0</version>
</Package>
EOF
    
    log_debug "Created temporary manifest: $TEMP_MANIFEST"
    
    # Retrieve using manifest
    retrieve_by_manifest "$TEMP_MANIFEST"
    
    # Cleanup
    rm -f "$TEMP_MANIFEST"
}

# Retrieve using manifest file
retrieve_by_manifest() {
    local MANIFEST="$1"
    
    if [ ! -f "$MANIFEST" ]; then
        log_error "Manifest file not found: $MANIFEST"
        exit 1
    fi
    
    log_info "Retrieving metadata using manifest: $MANIFEST"
    
    if [ "$VERBOSE" = true ]; then
        log_debug "Manifest contents:"
        cat "$MANIFEST" | head -20
        echo ""
    fi
    
    # Create output directory if it doesn't exist
    mkdir -p "$OUTPUT_DIR"
    
    # Retrieve metadata
    RETRIEVE_CMD="sf project retrieve start --manifest $MANIFEST --target-org $ORG_ALIAS --wait $WAIT_TIME"
    
    if [ "$VERBOSE" = true ]; then
        $RETRIEVE_CMD || {
            log_error "Metadata retrieval failed"
            exit 1
        }
    else
        log_info "Retrieving metadata (this may take a few minutes)..."
        $RETRIEVE_CMD > /dev/null 2>&1 || {
            log_error "Metadata retrieval failed"
            echo ""
            echo "Run with --verbose to see detailed error messages"
            exit 1
        }
    fi
    
    log_success "Metadata retrieved successfully!"
    log_info "Output directory: $OUTPUT_DIR"
}

# Retrieve using metadata file
retrieve_by_file() {
    if [ ! -f "$METADATA_FILE" ]; then
        log_error "Metadata file not found: $METADATA_FILE"
        exit 1
    fi
    
    log_info "Reading metadata from file: $METADATA_FILE"
    
    # Parse file and create manifest
    TEMP_MANIFEST=$(mktemp)
    cat > "$TEMP_MANIFEST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
EOF
    
    CURRENT_TYPE=""
    MEMBERS=()
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        line=$(echo "$line" | xargs)
        if [ -z "$line" ] || [[ "$line" =~ ^# ]]; then
            continue
        fi
        
        # Check if line is a metadata type (starts with uppercase, no dots)
        if [[ "$line" =~ ^[A-Z][a-zA-Z]*$ ]] && [[ ! "$line" =~ \. ]]; then
            # Close previous type if exists
            if [ -n "$CURRENT_TYPE" ] && [ ${#MEMBERS[@]} -gt 0 ]; then
                echo "    <types>" >> "$TEMP_MANIFEST"
                for member in "${MEMBERS[@]}"; do
                    echo "        <members>$member</members>" >> "$TEMP_MANIFEST"
                done
                echo "        <name>$CURRENT_TYPE</name>" >> "$TEMP_MANIFEST"
                echo "    </types>" >> "$TEMP_MANIFEST"
            fi
            
            CURRENT_TYPE="$line"
            MEMBERS=()
            log_info "  Found metadata type: $CURRENT_TYPE"
        else
            # It's a member name
            if [ -n "$CURRENT_TYPE" ]; then
                MEMBERS+=("$line")
                log_debug "    Adding member: $line"
            else
                log_warn "Skipping line (no type specified): $line"
            fi
        fi
    done < "$METADATA_FILE"
    
    # Close last type
    if [ -n "$CURRENT_TYPE" ] && [ ${#MEMBERS[@]} -gt 0 ]; then
        echo "    <types>" >> "$TEMP_MANIFEST"
        for member in "${MEMBERS[@]}"; do
            echo "        <members>$member</members>" >> "$TEMP_MANIFEST"
        done
        echo "        <name>$CURRENT_TYPE</name>" >> "$TEMP_MANIFEST"
        echo "    </types>" >> "$TEMP_MANIFEST"
    fi
    
    cat >> "$TEMP_MANIFEST" << EOF
    <version>60.0</version>
</Package>
EOF
    
    log_debug "Created manifest from file: $TEMP_MANIFEST"
    
    if [ "$VERBOSE" = true ]; then
        log_debug "Generated manifest:"
        cat "$TEMP_MANIFEST"
        echo ""
    fi
    
    # Retrieve using manifest
    retrieve_by_manifest "$TEMP_MANIFEST"
    
    # Cleanup
    rm -f "$TEMP_MANIFEST"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--alias)
            ORG_ALIAS="$2"
            shift 2
            ;;
        -i|--instance-url)
            INSTANCE_URL="$2"
            shift 2
            ;;
        -t|--metadata-types)
            METADATA_TYPES="$2"
            shift 2
            ;;
        -f|--metadata-file)
            METADATA_FILE="$2"
            shift 2
            ;;
        -m|--manifest)
            MANIFEST_FILE="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -w|--wait)
            WAIT_TIME="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --add-org|--new-org)
            ADD_NEW_ORG=true
            shift
            ;;
        --list-orgs)
            list_orgs
            exit 0
            ;;
        --list-metadata-types)
            # Will be handled after parsing, need ORG_ALIAS
            shift
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
            # If no option specified, treat as org alias
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

# Handle list-metadata-types after parsing
if [ -n "$ORG_ALIAS" ] && [ "$1" = "--list-metadata-types" ]; then
    list_metadata_types
    exit 0
fi

# Main execution
echo "=========================================="
echo "📥 Salesforce Asset Retrieval"
echo "=========================================="
echo ""

check_cli

# Handle adding a new org
if [ "$ADD_NEW_ORG" = true ]; then
    add_new_org
    # After adding, continue with retrieval if metadata specified
    if [ -z "$METADATA_TYPES" ] && [ -z "$METADATA_FILE" ] && [ -z "$MANIFEST_FILE" ]; then
        log_info "Org added successfully. No metadata specified for retrieval."
        echo ""
        echo "To retrieve metadata, run:"
        echo "  $0 -a $ORG_ALIAS -t CustomObject,ApexClass"
        echo "  $0 -a $ORG_ALIAS -f metadata-example.txt"
        echo "  $0 -a $ORG_ALIAS -m manifest/package.xml"
        exit 0
    fi
fi

# If no org specified, list available orgs
if [ -z "$ORG_ALIAS" ]; then
    log_warn "No org alias specified"
    echo ""
    list_orgs
    echo ""
    echo "Options:"
    echo "  1. Enter an existing org alias to use"
    echo "  2. Use --add-org to add a new org"
    echo ""
    read -p "Enter org alias to use (or press Enter to add new): " ORG_ALIAS
    if [ -z "$ORG_ALIAS" ]; then
        echo ""
        read -p "Do you want to add a new org? (Y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            ADD_NEW_ORG=true
            add_new_org
        else
            log_error "Org alias is required"
            exit 1
        fi
    fi
fi

# Authenticate if needed (unless we just added a new org)
if [ "$ADD_NEW_ORG" != true ]; then
    authenticate_org
fi

# Verify org
verify_org

echo ""
echo "Target org: $ORG_USERNAME"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Determine retrieval method
if [ -n "$MANIFEST_FILE" ]; then
    retrieve_by_manifest "$MANIFEST_FILE"
elif [ -n "$METADATA_FILE" ]; then
    retrieve_by_file
elif [ -n "$METADATA_TYPES" ]; then
    retrieve_by_types
else
    log_error "No retrieval method specified"
    echo ""
    echo "You must specify one of:"
    echo "  -t, --metadata-types    Comma-separated metadata types"
    echo "  -f, --metadata-file     File containing metadata"
    echo "  -m, --manifest          Manifest file (package.xml)"
    echo ""
    show_usage
    exit 1
fi

echo ""
log_success "Retrieval completed!"
echo ""
echo "Retrieved metadata is in: $OUTPUT_DIR"

