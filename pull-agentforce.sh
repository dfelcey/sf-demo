#!/bin/bash
# Convenience script to pull Agentforce agent assets, external services, and named credentials
# This is a wrapper around pull-assets.sh with Agentforce-specific defaults

set +e

# Default values
VERBOSE=false
ORG_ALIAS=""
OUTPUT_DIR="force-app"
METADATA_FILE="agentforce-metadata.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Pull Agentforce agent assets, external services, and named credentials from a Salesforce org.

This script retrieves:
  - Agentforce Agents (complete agent configurations)
  - Bot and BotVersion (agent components)
  - AiAuthoringBundle (Agent Script files - Next Generation Agentforce agents)
  - GenAI Functions (actions that can be added to agents)
  - GenAI Plugins (topics/categories of actions)
  - GenAI Planner Bundles (agent planner configurations)
  - External Service Registrations
  - Named Credentials
  - External Credentials
  - Connected Apps
  - Custom Metadata Types
  - Apex Classes (invocable actions)
  - Flows (including flow actions)

Options:
  -a, --alias ALIAS          Org alias (required)
  -o, --output-dir DIR        Output directory (default: force-app)
  -f, --metadata-file FILE    Custom metadata file (default: agentforce-metadata.txt)
  --verbose                   Enable verbose output
  -h, --help                 Show this help message

Examples:
  # Pull Agentforce assets from an org
  $0 -a my-org

  # Pull to custom directory
  $0 -a my-org -o agentforce-assets

  # Use custom metadata file
  $0 -a my-org -f custom-agentforce.txt

  # Verbose mode
  $0 -a my-org --verbose

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--alias)
            ORG_ALIAS="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -f|--metadata-file)
            METADATA_FILE="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
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

# Check if metadata file exists
if [ ! -f "$METADATA_FILE" ]; then
    log_error "Metadata file not found: $METADATA_FILE"
    echo ""
    echo "The metadata file should contain Agentforce-related metadata types."
    echo "Default file: agentforce-metadata.txt"
    echo ""
    echo "Create it or specify a different file with -f"
    exit 1
fi

# Check if pull-assets.sh exists
if [ ! -f "pull-assets.sh" ]; then
    log_error "pull-assets.sh not found!"
    echo ""
    echo "This script requires pull-assets.sh to be in the same directory."
    exit 1
fi

# Main execution
echo "=========================================="
echo "🤖 Agentforce Asset Retrieval"
echo "=========================================="
echo ""
echo "This will retrieve:"
echo "  • Agent Script files (AiAuthoringBundle - Next Generation agents)"
echo "  • Bot and BotVersion (agent configurations)"
echo "  • GenAI Functions, Plugins, and Planner Bundles"
echo "  • External Service Registrations"
echo "  • Named Credentials"
echo "  • External Credentials"
echo "  • Connected Apps"
echo "  • Custom Metadata Types"
echo "  • Apex Classes (invocable actions)"
echo "  • Flows (including flow actions)"
echo ""

if [ -z "$ORG_ALIAS" ]; then
    log_error "Org alias is required"
    echo ""
    echo "Usage: $0 -a ORG_ALIAS"
    echo ""
    echo "To see available orgs:"
    echo "  ./pull-assets.sh --list-orgs"
    exit 1
fi

# Query permission sets assigned to current user that are related to agents
log_info "Querying permission sets assigned to current user..."

# Get current user info
ORG_INFO=$(sf org display --target-org "$ORG_ALIAS" --json 2>/dev/null || echo '{}')
CURRENT_USERNAME=$(echo "$ORG_INFO" | jq -r '.result.username // ""' 2>/dev/null || echo "")

if [ -n "$CURRENT_USERNAME" ]; then
    log_info "Current user: $CURRENT_USERNAME"
    
    # Query permission sets assigned to current user
    # Using SOQL to get permission sets assigned to the current user
    PERMISSION_SETS_QUERY="SELECT PermissionSet.Name, PermissionSet.Label FROM PermissionSetAssignment WHERE Assignee.Username = '$CURRENT_USERNAME'"
    
    log_info "Finding permission sets assigned to current user..."
    PERMISSION_SETS_JSON=$(sf data query --query "$PERMISSION_SETS_QUERY" --target-org "$ORG_ALIAS" --json 2>/dev/null || echo '{"result":{"records":[]}}')
    
    PERMISSION_SET_NAMES=$(echo "$PERMISSION_SETS_JSON" | jq -r '.result.records[]?.PermissionSet?.Name // empty' 2>/dev/null | grep -v '^$' || echo "")
    
    if [ -n "$PERMISSION_SET_NAMES" ]; then
        log_info "Found permission sets assigned to current user:"
        echo "$PERMISSION_SET_NAMES" | while read -r ps_name; do
            if [ -n "$ps_name" ]; then
                echo "  • $ps_name"
            fi
        done
        
        # Include all permission sets assigned to the user
        # (They may have agent-related permissions)
        log_info "Including all permission sets assigned to current user..."
        AGENT_RELATED_PS="$PERMISSION_SET_NAMES"
        
        if [ -n "$AGENT_RELATED_PS" ]; then
            log_success "Found permission sets assigned to current user"
            
            # Create temporary metadata file with filtered permission sets
            TEMP_METADATA_FILE=$(mktemp)
            
            # Replace PermissionSet section with actual permission set names
            # Find the line with "PermissionSet" and replace until the comment line
            {
                # Print everything before PermissionSet
                sed '/^PermissionSet$/,$d' "$METADATA_FILE"
                # Add PermissionSet header
                echo "PermissionSet"
                # Add each permission set name
                echo "$AGENT_RELATED_PS" | grep -v '^$' | while read -r ps_name; do
                    if [ -n "$ps_name" ]; then
                        echo "$ps_name"
                    fi
                done
                # Print everything after the comment line (skip the comment itself)
                sed -n '/^# Will be populated dynamically/,$p' "$METADATA_FILE" | tail -n +2
            } > "$TEMP_METADATA_FILE" 2>/dev/null || {
                # Fallback: use awk for more reliable replacement
                awk -v ps_list="$AGENT_RELATED_PS" '
                BEGIN {
                    split(ps_list, ps_array, "\n")
                }
                /^PermissionSet$/ {
                    print
                    for (i in ps_array) {
                        if (ps_array[i] != "") {
                            print ps_array[i]
                        }
                    }
                    skip_until_comment = 1
                    next
                }
                skip_until_comment && /^# Will be populated dynamically/ {
                    skip_until_comment = 0
                    next
                }
                skip_until_comment {
                    next
                }
                { print }
                ' "$METADATA_FILE" > "$TEMP_METADATA_FILE" 2>/dev/null || cp "$METADATA_FILE" "$TEMP_METADATA_FILE"
            }
            
            METADATA_FILE="$TEMP_METADATA_FILE"
            log_info "Using permission sets assigned to current user in temporary metadata file"
        else
            log_warn "No permission sets found assigned to current user"
            # Remove PermissionSet section from metadata file
            TEMP_METADATA_FILE=$(mktemp)
            awk '/^PermissionSet$/,/^# Will be populated dynamically/ { if (/^PermissionSet$/ || /^# Will be populated dynamically/) next; next } { print }' "$METADATA_FILE" > "$TEMP_METADATA_FILE" 2>/dev/null || cp "$METADATA_FILE" "$TEMP_METADATA_FILE"
            METADATA_FILE="$TEMP_METADATA_FILE"
        fi
    else
        log_warn "No permission sets found assigned to current user"
        # Remove PermissionSet section from metadata file
        TEMP_METADATA_FILE=$(mktemp)
        awk '/^PermissionSet$/,/^# Will be populated dynamically/ { if (/^PermissionSet$/ || /^# Will be populated dynamically/) next; next } { print }' "$METADATA_FILE" > "$TEMP_METADATA_FILE" 2>/dev/null || cp "$METADATA_FILE" "$TEMP_METADATA_FILE"
        METADATA_FILE="$TEMP_METADATA_FILE"
    fi
else
    log_warn "Could not determine current user, skipping permission set filtering"
fi

# Build command
CMD="./pull-assets.sh -a $ORG_ALIAS -f $METADATA_FILE -o $OUTPUT_DIR"

if [ "$VERBOSE" = true ]; then
    CMD="$CMD --verbose"
fi

log_info "Executing: $CMD"
echo ""

# Execute pull-assets.sh
$CMD

EXIT_CODE=$?

# Clean up temporary metadata file if created
if [ -n "$TEMP_METADATA_FILE" ] && [ -f "$TEMP_METADATA_FILE" ]; then
    rm -f "$TEMP_METADATA_FILE"
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    log_success "Agentforce assets retrieved successfully!"
    echo ""
    echo "Retrieved assets are in: $OUTPUT_DIR"
    echo ""
    echo "Key locations:"
    echo "  • Agent Script files: $OUTPUT_DIR/main/default/aiAuthoringBundles/"
    echo "  • Agents (Bots): $OUTPUT_DIR/main/default/bots/"
    echo "  • Bot Versions: $OUTPUT_DIR/main/default/botVersions/"
    echo "  • GenAI Planner Bundles: $OUTPUT_DIR/main/default/genAiPlannerBundles/"
    echo "  • GenAI Functions: $OUTPUT_DIR/main/default/genAiFunctions/"
    echo "  • GenAI Plugins: $OUTPUT_DIR/main/default/genAiPlugins/"
    echo "  • Permission Sets: $OUTPUT_DIR/main/default/permissionsets/"
    echo "  • External Services: $OUTPUT_DIR/main/default/externalServiceRegistrations/"
    echo "  • Named Credentials: $OUTPUT_DIR/main/default/namedCredentials/"
    echo "  • External Credentials: $OUTPUT_DIR/main/default/externalCredentials/"
else
    log_error "Failed to retrieve Agentforce assets"
    exit $EXIT_CODE
fi

