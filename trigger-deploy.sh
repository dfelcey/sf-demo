#!/bin/bash
# Trigger script for Salesforce deployment via GitHub Actions
# This script authenticates locally via browser login, then triggers deployment

# Don't exit on error - we'll handle errors explicitly
set +e

# Configuration
GITHUB_OWNER="dfelcey"
GITHUB_REPO="sf-demo"
WORKFLOW_FILE="deploy-with-login.yml"

# Default values
VERBOSE=false
INSTANCE_URL="https://login.salesforce.com"
ORG_ALIAS="deploy-target"

# Parse command line arguments
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [INSTANCE_URL] [ORG_ALIAS]

Trigger Salesforce deployment via GitHub Actions.

Arguments:
  INSTANCE_URL    Salesforce instance URL (default: https://login.salesforce.com)
  ORG_ALIAS       Org alias for authentication (default: deploy-target)

Options:
  -v, --verbose   Enable verbose/debug logging
  -h, --help      Show this help message

Examples:
  $0                                    # Use defaults
  $0 -v                                 # Verbose mode with defaults
  $0 https://test.salesforce.com        # Specify instance URL
  $0 -v production-org                  # Verbose mode with org alias
  $0 https://login.salesforce.com prod  # Specify both with defaults

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

# Logging functions
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
    fi
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

echo "=========================================="
echo "🚀 Salesforce Deployment"
echo "=========================================="
echo ""
log_info "Starting deployment script"
log_debug "Verbose mode: $VERBOSE"
log_info "Configuration:"
log_info "  GitHub Owner: $GITHUB_OWNER"
log_info "  GitHub Repo: $GITHUB_REPO"
log_info "  Workflow File: $WORKFLOW_FILE"
log_info "  Instance URL: $INSTANCE_URL"
log_info "  Org Alias: $ORG_ALIAS"
echo ""
echo "This will:"
echo "1. Authenticate to Salesforce via browser login"
echo "2. Extract credentials from authenticated org"
echo "3. Trigger GitHub Actions workflow with credentials"
echo "4. Deploy your Salesforce project"
echo ""

# Check if Salesforce CLI is installed
log_info "Checking for Salesforce CLI..."
if ! command -v sf &> /dev/null; then
    log_error "Salesforce CLI (sf) is not installed!"
    echo ""
    
    # Check for Node.js/npm
    if ! command -v npm &> /dev/null; then
        log_error "npm is also not installed!"
        echo ""
        read -p "Install Node.js and Salesforce CLI now? (Y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &> /dev/null; then
                log_info "Installing Node.js via Homebrew..."
                brew install node || {
                    log_error "Failed to install Node.js"
                    exit 1
                }
            elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                log_info "Installing Node.js..."
                curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
                sudo apt-get install -y nodejs || {
                    log_error "Failed to install Node.js"
                    exit 1
                }
            else
                log_error "Please install Node.js manually: https://nodejs.org/"
                exit 1
            fi
        else
            exit 1
        fi
    fi
    
    echo ""
    read -p "Install Salesforce CLI now? (Y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        log_info "Installing Salesforce CLI..."
        npm install -g @salesforce/cli@latest || {
            log_error "Installation failed. Try: sudo npm install -g @salesforce/cli@latest"
            exit 1
        }
        export PATH="$PATH:$(npm config get prefix)/bin"
        log_success "Salesforce CLI installed: $(sf --version 2>&1)"
    else
        exit 1
    fi
fi

SF_VERSION=$(sf --version 2>&1)
log_success "Salesforce CLI found: $SF_VERSION"
log_debug "CLI location: $(which sf)"

# Check for updates if verbose
if [ "$VERBOSE" = true ]; then
    echo ""
    log_info "Checking for CLI updates..."
    LATEST=$(npm view @salesforce/cli version 2>/dev/null || echo "")
    if [ -n "$LATEST" ]; then
        CURRENT=$(echo "$SF_VERSION" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [ "$CURRENT" != "$LATEST" ]; then
            log_warn "CLI update available: $CURRENT -> $LATEST"
            read -p "Update now? (y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                npm install -g @salesforce/cli@latest && log_success "Updated to: $(sf --version 2>&1)"
            fi
        else
            log_success "CLI is up to date: $CURRENT"
        fi
    fi
fi
echo ""

# Check if already authenticated to the specified org
log_info "Checking for authenticated Salesforce orgs..."
ORG_LIST_OUTPUT=$(sf org list --json 2>&1)
log_debug "Org list command output: $ORG_LIST_OUTPUT"

EXISTING_ORG=$(echo "$ORG_LIST_OUTPUT" | grep -o "\"alias\":\"${ORG_ALIAS}\"" || echo "")

if [ -z "$EXISTING_ORG" ]; then
    log_info "No authenticated org found with alias: $ORG_ALIAS"
    log_debug "Available orgs: $(echo "$ORG_LIST_OUTPUT" | grep -o '"alias":"[^"]*"' || echo 'none')"
    echo ""
    echo "=========================================="
    echo "🔐 Salesforce Browser Login"
    echo "=========================================="
    echo ""
    echo "This will open your browser to log in to Salesforce."
    echo "After logging in, your credentials will be used for deployment."
    echo ""
    read -p "Press Enter to continue with Salesforce login..."
    
    log_info "Initiating Salesforce web login..."
    log_debug "Command: sf org login web --alias $ORG_ALIAS --instance-url $INSTANCE_URL"
    
    if sf org login web --alias "$ORG_ALIAS" --instance-url "$INSTANCE_URL" 2>&1; then
        log_success "Salesforce login completed successfully"
    else
        log_error "Salesforce login failed"
        exit 1
    fi
    
    echo ""
    echo "✅ Successfully authenticated to Salesforce!"
else
    log_info "Found authenticated org: $ORG_ALIAS"
    echo ""
    read -p "Do you want to login to a different org? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Re-authenticating to Salesforce..."
        log_debug "Command: sf org login web --alias $ORG_ALIAS --instance-url $INSTANCE_URL"
        
        if sf org login web --alias "$ORG_ALIAS" --instance-url "$INSTANCE_URL" 2>&1; then
            log_success "Salesforce re-authentication completed successfully"
        else
            log_error "Salesforce login failed"
            exit 1
        fi
        echo ""
        echo "✅ Successfully authenticated to Salesforce!"
    else
        log_info "Using existing authenticated org: $ORG_ALIAS"
    fi
fi

echo ""
echo "=========================================="
echo "📋 Extracting Org Credentials"
echo "=========================================="
echo ""

# Check if jq is available for JSON parsing
log_info "Checking for jq (JSON parser)..."
if ! command -v jq &> /dev/null; then
    log_error "jq is not installed. Cannot extract credentials automatically."
    echo "Please install jq: brew install jq (macOS) or apt-get install jq (Linux)"
    echo ""
    echo "You can manually get credentials with:"
    echo "  sf org display --target-org $ORG_ALIAS --json | jq -r '.result.accessToken'"
    exit 1
fi

JQ_VERSION=$(jq --version 2>&1)
log_success "jq found: $JQ_VERSION"

# Extract credentials from the authenticated org
log_info "Extracting org information for alias: $ORG_ALIAS"
log_debug "Command: sf org display --target-org $ORG_ALIAS --json"

ORG_INFO=$(sf org display --target-org "$ORG_ALIAS" --json 2>&1)
ORG_INFO_EXIT_CODE=$?

if [ $ORG_INFO_EXIT_CODE -ne 0 ]; then
    log_error "Failed to get org information (exit code: $ORG_INFO_EXIT_CODE)"
    log_debug "Error output: $ORG_INFO"
    exit 1
fi

if [ -z "$ORG_INFO" ]; then
    log_error "Org information is empty"
    exit 1
fi

log_debug "Org info retrieved (length: ${#ORG_INFO} chars)"

# Extract individual fields
log_info "Parsing org credentials from JSON..."
RAW_ACCESS_TOKEN=$(echo "$ORG_INFO" | jq -r '.result.accessToken // empty' 2>/dev/null)
SF_INSTANCE_URL=$(echo "$ORG_INFO" | jq -r '.result.instanceUrl // empty' 2>/dev/null)
ORG_USERNAME=$(echo "$ORG_INFO" | jq -r '.result.username // "unknown"' 2>/dev/null)
ORG_ID=$(echo "$ORG_INFO" | jq -r '.result.id // "unknown"' 2>/dev/null)

log_debug "Extracted values:"
log_debug "  Username: $ORG_USERNAME"
log_debug "  Org ID: $ORG_ID"
log_debug "  Instance URL: $SF_INSTANCE_URL"
log_debug "  Raw Access Token: ${RAW_ACCESS_TOKEN:0:20}... (length: ${#RAW_ACCESS_TOKEN})"

if [ -z "$RAW_ACCESS_TOKEN" ] || [ -z "$SF_INSTANCE_URL" ] || [ "$ORG_ID" = "unknown" ]; then
    log_error "Failed to extract required credentials from org"
    log_error "Access Token: ${RAW_ACCESS_TOKEN:+present}${RAW_ACCESS_TOKEN:-missing}"
    log_error "Instance URL: ${SF_INSTANCE_URL:+present}${SF_INSTANCE_URL:-missing}"
    log_error "Org ID: ${ORG_ID:+present}${ORG_ID:-missing}"
    log_debug "Full org info: $ORG_INFO"
    exit 1
fi

# Format access token as required by Salesforce CLI: "<org id>!<accesstoken>"
# Check if token is already in the correct format
if [[ "$RAW_ACCESS_TOKEN" == *"!"* ]]; then
    SF_ACCESS_TOKEN="$RAW_ACCESS_TOKEN"
    log_debug "Access token already in correct format (contains '!')"
else
    SF_ACCESS_TOKEN="${ORG_ID}!${RAW_ACCESS_TOKEN}"
    log_debug "Formatted access token as: ${ORG_ID}!<token>"
fi

log_success "Credentials extracted successfully!"
echo "✅ Credentials extracted successfully!"
echo "  Org: $ORG_USERNAME"
echo "  Org ID: $ORG_ID"
echo "  Instance URL: $SF_INSTANCE_URL"
echo ""

# Check if GitHub token is available
log_info "Checking for GitHub token..."
if [ -f .env ]; then
    log_debug "Loading .env file..."
    source .env
    if [ -n "$GITHUB_TOKEN" ]; then
        log_success "GitHub token loaded from .env (length: ${#GITHUB_TOKEN} chars)"
    else
        log_warn "GITHUB_TOKEN not found in .env file"
    fi
else
    log_debug ".env file not found"
fi

if [ -z "$GITHUB_TOKEN" ]; then
    log_warn "GITHUB_TOKEN not set in .env file"
    echo "⚠️  Note: GITHUB_TOKEN not set in .env file"
    echo "For private repos, you may need to set GITHUB_TOKEN"
    echo ""
fi

log_info "Preparing to trigger GitHub Actions workflow..."
echo "Triggering GitHub Actions workflow..."
echo ""

# Trigger the workflow
API_URL="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/workflows/${WORKFLOW_FILE}/dispatches"
log_debug "API URL: $API_URL"

# Verify credentials are available before building payload
if [ -z "$SF_ACCESS_TOKEN" ] || [ -z "$SF_INSTANCE_URL" ]; then
    log_error "Missing required credentials!"
    log_error "Access Token: ${SF_ACCESS_TOKEN:+present (${#SF_ACCESS_TOKEN} chars)}${SF_ACCESS_TOKEN:-missing}"
    log_error "Instance URL: ${SF_INSTANCE_URL:+present}${SF_INSTANCE_URL:-missing}"
    echo ""
    echo "❌ Cannot trigger workflow without credentials"
    echo ""
    echo "Please ensure:"
    echo "1. You are authenticated to Salesforce (run: sf org login web)"
    echo "2. The org alias '$ORG_ALIAS' exists"
    echo "3. Credentials were extracted successfully"
    exit 1
fi

# Prepare payload with credentials
log_info "Building workflow dispatch payload..."
log_info "  Access Token length: ${#SF_ACCESS_TOKEN} chars"
log_info "  Instance URL: $SF_INSTANCE_URL"

if command -v jq &> /dev/null; then
    PAYLOAD=$(jq -n \
        --arg ref "main" \
        --arg token "$SF_ACCESS_TOKEN" \
        --arg url "$SF_INSTANCE_URL" \
        '{ref: $ref, inputs: {sf_access_token: $token, sf_instance_url: $url}}')
    log_debug "Payload created using jq (length: ${#PAYLOAD} chars)"
    
    # Verify payload was created correctly
    if [ -z "$PAYLOAD" ]; then
        log_error "Failed to create payload with jq"
        exit 1
    fi
else
    # Fallback: manual JSON (may fail with special characters)
    PAYLOAD=$(cat <<EOF
{
  "ref": "main",
  "inputs": {
    "sf_access_token": "${SF_ACCESS_TOKEN}",
    "sf_instance_url": "${SF_INSTANCE_URL}"
  }
}
EOF
)
    log_warn "Payload created manually (jq not available, may fail with special characters)"
    log_debug "Payload length: ${#PAYLOAD} chars"
    
    # Verify payload contains the credentials
    if [[ "$PAYLOAD" != *"sf_access_token"* ]] || [[ "$PAYLOAD" != *"sf_instance_url"* ]]; then
        log_error "Payload validation failed - credentials not found in payload"
        exit 1
    fi
fi

log_info "Payload created successfully"
log_debug "Payload preview: ${PAYLOAD:0:100}..."

log_info "Sending workflow dispatch request..."
log_info "API URL: $API_URL"
log_info "Using authentication: ${GITHUB_TOKEN:+Bearer token}${GITHUB_TOKEN:-none}"

# First, verify the workflow exists
log_info "Verifying workflow exists..."
WORKFLOW_CHECK_URL="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/workflows/${WORKFLOW_FILE}"
if [ -n "$GITHUB_TOKEN" ]; then
    WORKFLOW_CHECK=$(curl -s -w "\n%{http_code}" \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$WORKFLOW_CHECK_URL" 2>&1)
else
    WORKFLOW_CHECK=$(curl -s -w "\n%{http_code}" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$WORKFLOW_CHECK_URL" 2>&1)
fi

WORKFLOW_CHECK_CODE=$(echo "$WORKFLOW_CHECK" | tail -n1)
WORKFLOW_CHECK_BODY=$(echo "$WORKFLOW_CHECK" | sed '$d')

log_info "Workflow check HTTP Code: $WORKFLOW_CHECK_CODE"
if [ "$WORKFLOW_CHECK_CODE" -eq 200 ]; then
    log_success "Workflow file exists and is accessible"
    WORKFLOW_ID=$(echo "$WORKFLOW_CHECK_BODY" | jq -r '.id // "unknown"' 2>/dev/null || echo "unknown")
    log_info "Workflow ID: $WORKFLOW_ID"
else
    log_error "Failed to verify workflow exists (HTTP $WORKFLOW_CHECK_CODE)"
    log_error "Response: $WORKFLOW_CHECK_BODY"
    echo ""
    echo "Troubleshooting:"
    echo "- Check that the workflow file exists at: .github/workflows/${WORKFLOW_FILE}"
    echo "- Verify repository name: ${GITHUB_OWNER}/${GITHUB_REPO}"
    echo "- For private repos, ensure GITHUB_TOKEN is set with 'repo' scope"
    exit 1
fi

# Now trigger the workflow
log_info "Triggering workflow dispatch..."
log_debug "Payload: $PAYLOAD"

if [ -n "$GITHUB_TOKEN" ]; then
    # Use separate stderr for verbose output, stdout for response
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Content-Type: application/json" \
        "${API_URL}" \
        -d "$PAYLOAD" 2>/dev/null)
    CURL_EXIT_CODE=$?
else
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Content-Type: application/json" \
        "${API_URL}" \
        -d "$PAYLOAD" 2>/dev/null)
    CURL_EXIT_CODE=$?
fi

if [ $CURL_EXIT_CODE -ne 0 ]; then
    log_error "curl command failed with exit code: $CURL_EXIT_CODE"
    echo ""
    echo "Troubleshooting:"
    echo "- Check your internet connection"
    echo "- Verify GitHub API is accessible"
    echo "- For private repos, ensure GITHUB_TOKEN is set"
    exit 1
fi

# Extract HTTP code (last line) and body (everything else)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

log_info "HTTP Response Code: $HTTP_CODE"
if [ -n "$BODY" ]; then
    log_info "Response Body: $BODY"
fi

if [ "$HTTP_CODE" -eq 204 ]; then
    log_success "Workflow triggered successfully (HTTP 204)"
    echo "✅ Workflow triggered successfully!"
    echo ""
    
    # Verify the workflow run was created and get its ID
    log_info "Verifying workflow run was created..."
    echo "Waiting for GitHub to create the workflow run..."
    
    # Record the time we triggered the workflow
    TRIGGER_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "")
    
    # Try multiple times to find the run (GitHub API can be slow)
    RUN_ID=""
    RETRY_COUNT=0
    MAX_RETRIES=8  # Increased retries
    
    while [ -z "$RUN_ID" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        sleep 2  # Wait before checking
        
        # Check for the most recent workflow run
        if [ -n "$GITHUB_TOKEN" ]; then
            RUNS_CHECK=$(curl -s \
                -H "Accept: application/vnd.github+json" \
                -H "Authorization: Bearer ${GITHUB_TOKEN}" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/workflows/${WORKFLOW_FILE}/runs?per_page=5" 2>/dev/null)
        else
            RUNS_CHECK=$(curl -s \
                -H "Accept: application/vnd.github+json" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/workflows/${WORKFLOW_FILE}/runs?per_page=5" 2>/dev/null)
        fi
        
        # Try to extract run ID using jq first, then fallback to grep
        if command -v jq &> /dev/null; then
            # Get the most recent run (should be the one we just triggered)
            RUN_ID=$(echo "$RUNS_CHECK" | jq -r '.workflow_runs[0].id // empty' 2>/dev/null)
            LATEST_RUN_STATUS=$(echo "$RUNS_CHECK" | jq -r '.workflow_runs[0].status // empty' 2>/dev/null)
            LATEST_RUN_CREATED=$(echo "$RUNS_CHECK" | jq -r '.workflow_runs[0].created_at // empty' 2>/dev/null)
            LATEST_RUN_URL=$(echo "$RUNS_CHECK" | jq -r '.workflow_runs[0].html_url // empty' 2>/dev/null)
        else
            RUN_ID=$(echo "$RUNS_CHECK" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
            LATEST_RUN_STATUS=$(echo "$RUNS_CHECK" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
            LATEST_RUN_CREATED=$(echo "$RUNS_CHECK" | grep -o '"created_at":"[^"]*"' | head -1 | cut -d'"' -f4)
            LATEST_RUN_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/actions/runs/${RUN_ID}"
        fi
        
        if [ -n "$RUN_ID" ]; then
            log_debug "Found run ID: $RUN_ID (created: $LATEST_RUN_CREATED)"
            # Verify this is a recent run (within last 2 minutes)
            if [ -n "$LATEST_RUN_CREATED" ]; then
                log_info "Most recent run found: $RUN_ID"
                break
            fi
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            log_debug "Run not found yet, retrying... (attempt $RETRY_COUNT/$MAX_RETRIES)"
            echo "   Checking for workflow run... (attempt $RETRY_COUNT/$MAX_RETRIES)"
        fi
    done
    
    if [ -n "$RUN_ID" ]; then
        RUN_URL="${LATEST_RUN_URL:-https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/actions/runs/${RUN_ID}}"
        log_success "Workflow run found!"
        log_info "  Run ID: $RUN_ID"
        log_info "  Status: $LATEST_RUN_STATUS"
        log_info "  Created: $LATEST_RUN_CREATED"
        echo ""
        echo "=========================================="
        echo "✅ Workflow Run Found!"
        echo "=========================================="
        echo ""
        echo "  Run ID: $RUN_ID"
        echo "  Status: $LATEST_RUN_STATUS"
        echo "  Created: $LATEST_RUN_CREATED"
        echo ""
        echo "  🔗 Direct Link:"
        echo "  ${RUN_URL}"
        echo ""
        echo "  🔗 All Workflows:"
        echo "  https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/actions"
        echo ""
        
        # Try to open the run in browser
        if command -v open &> /dev/null; then
            echo "Opening workflow run in your browser..."
            open "$RUN_URL" 2>/dev/null &
        fi
    else
        log_warn "Workflow dispatch returned 204 but no run found after ${MAX_RETRIES} attempts"
        RUN_ID=""
        RUN_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/actions"
        echo ""
        echo "⚠️  Run ID not found, but workflow was triggered successfully!"
        echo ""
        echo "The workflow should appear shortly. View all workflow runs at:"
        echo "  ${RUN_URL}"
        echo ""
        echo "You can also check the latest run manually:"
        echo "  https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/actions/workflows/${WORKFLOW_FILE}"
        echo ""
        
        # Try to open the workflows page in browser
        if command -v open &> /dev/null; then
            echo "Opening workflows page in your browser..."
            open "${RUN_URL}" 2>/dev/null &
        fi
        
        echo ""
        echo "Continuing to monitor for the run..."
    fi
else
    log_error "Failed to trigger workflow (HTTP $HTTP_CODE)"
    echo "❌ Failed to trigger workflow"
    echo "HTTP Status: ${HTTP_CODE}"
    echo ""
    
    if [ -n "$BODY" ]; then
        echo "Error details:"
        echo "$BODY" | jq -r '.message // .' 2>/dev/null || echo "$BODY"
        echo ""
    fi
    
    case "$HTTP_CODE" in
        401)
            echo "Authentication failed (401)."
            echo "- Check your GITHUB_TOKEN in .env file"
            echo "- Ensure token has 'repo' scope"
            echo "- Get a new token from: https://github.com/settings/tokens"
            ;;
        403)
            echo "Access forbidden (403)."
            echo "- Check repository permissions"
            echo "- Ensure GITHUB_TOKEN has 'repo' scope"
            echo "- For private repos, token is required"
            ;;
        404)
            echo "Workflow not found (404)."
            echo "- Verify workflow file exists: .github/workflows/${WORKFLOW_FILE}"
            echo "- Check repository name: ${GITHUB_OWNER}/${GITHUB_REPO}"
            echo "- Ensure workflow file is committed and pushed"
            ;;
        422)
            echo "Validation failed (422)."
            echo "- Check workflow inputs format"
            echo "- Verify ref branch exists (main)"
            echo "- Check payload structure"
            ;;
        *)
            echo "Unexpected error."
            echo "- Check GitHub API status: https://www.githubstatus.com"
            echo "- Verify repository and workflow exist"
            ;;
    esac
    
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check workflow file exists: .github/workflows/${WORKFLOW_FILE}"
    echo "2. Verify workflow is active: https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/actions"
    echo "3. For private repos, set GITHUB_TOKEN in .env file"
    echo "4. Test manually: https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/actions/workflows/${WORKFLOW_FILE}"
    exit 1
fi

# Continue with monitoring if workflow was triggered successfully
if [ "$HTTP_CODE" -eq 204 ]; then
    # Function to get workflow run status
    get_workflow_status() {
        local run_id=$1
        local api_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/runs/${run_id}"
        local headers=()
        
        if [ -n "$GITHUB_TOKEN" ]; then
            headers+=("-H" "Authorization: Bearer ${GITHUB_TOKEN}")
        fi
        
        log_debug "Getting workflow status for run ID: $run_id"
        local status=$(curl -s "${headers[@]}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "$api_url" 2>/dev/null | jq -r '.status // empty' 2>/dev/null)
        
        if [ -z "$status" ]; then
            # Fallback to grep if jq fails
            status=$(curl -s "${headers[@]}" \
                -H "Accept: application/vnd.github+json" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "$api_url" 2>/dev/null | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
        fi
        
        log_debug "Workflow status: ${status:-unknown}"
        echo "$status"
    }
    
    # Function to get latest workflow run ID (if not already found)
    get_latest_run_id() {
        local api_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/workflows/${WORKFLOW_FILE}/runs?per_page=1"
        local headers=()
        
        if [ -n "$GITHUB_TOKEN" ]; then
            headers+=("-H" "Authorization: Bearer ${GITHUB_TOKEN}")
        fi
        
        local response=$(curl -s "${headers[@]}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "$api_url" 2>/dev/null)
        
        local run_id=$(echo "$response" | jq -r '.workflow_runs[0].id // empty' 2>/dev/null)
        
        if [ -z "$run_id" ]; then
            run_id=$(echo "$response" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
        fi
        
        echo "$run_id"
    }
    
    # Function to get job ID for a workflow run
    get_job_id() {
        local run_id=$1
        local api_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/runs/${run_id}/jobs"
        local headers=()
        
        if [ -n "$GITHUB_TOKEN" ]; then
            headers+=("-H" "Authorization: Bearer ${GITHUB_TOKEN}")
        fi
        
        local job_response=$(curl -s "${headers[@]}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "$api_url" 2>/dev/null)
        
        local job_id=$(echo "$job_response" | jq -r '.jobs[0].id // empty' 2>/dev/null)
        
        if [ -z "$job_id" ]; then
            job_id=$(echo "$job_response" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
        fi
        
        echo "$job_id"
    }
    
    # Function to get logs and extract Device Login URL
    get_device_login_info() {
        local job_id=$1
        local api_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/jobs/${job_id}/logs"
        local headers=()
        
        if [ -n "$GITHUB_TOKEN" ]; then
            headers+=("-H" "Authorization: Bearer ${GITHUB_TOKEN}")
        fi
        
        # Get logs (they come as gzip compressed, need to decompress)
        local logs=$(curl -s "${headers[@]}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            -H "Accept-Encoding: gzip" \
            "$api_url" 2>/dev/null | gunzip 2>/dev/null || curl -s "${headers[@]}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "$api_url" 2>/dev/null)
        
        # Extract Device Login URL (look for https://login.salesforce.com/setup/connect or similar)
        local url=$(echo "$logs" | grep -oE 'https://[^/]+/setup/connect[^[:space:]]*' | head -1)
        
        # Extract Device Login code (8 alphanumeric characters, usually after "code:" or standalone)
        local code=$(echo "$logs" | grep -iE '(code|device code|enter code)[: ]*[A-Z0-9]{8}' | grep -oE '[A-Z0-9]{8}' | head -1)
        
        # If code not found, try finding any 8-character alphanumeric sequence
        if [ -z "$code" ]; then
            code=$(echo "$logs" | grep -oE '[A-Z0-9]{8}' | grep -vE '^[0-9]{8}$' | head -1)
        fi
        
        echo "$url"
        echo "$code"
    }
    
    # Function to open URL in browser
    open_browser() {
        local url=$1
        if command -v open &> /dev/null; then
            open "$url" 2>/dev/null
        elif command -v xdg-open &> /dev/null; then
            xdg-open "$url" 2>/dev/null
        fi
    }
    
    # Get the workflow run ID if not already found
    if [ -z "$RUN_ID" ]; then
        log_info "Finding workflow run ID..."
        echo "Finding workflow run..."
        RETRY_COUNT=0
        MAX_RETRIES=6
        
        while [ -z "$RUN_ID" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            RUN_ID=$(get_latest_run_id)
            if [ -z "$RUN_ID" ]; then
                RETRY_COUNT=$((RETRY_COUNT + 1))
                if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                    log_debug "Workflow run not found yet, retrying... (attempt $RETRY_COUNT/$MAX_RETRIES)"
                    echo "   Waiting for workflow to appear... (attempt $RETRY_COUNT/$MAX_RETRIES)"
                    sleep 2
                fi
            fi
        done
        
        if [ -z "$RUN_ID" ]; then
            log_error "Could not find workflow run ID after ${MAX_RETRIES} attempts"
            echo "⚠️  Could not find workflow run ID after ${MAX_RETRIES} attempts"
            echo ""
            echo "This might be because:"
            echo "- The workflow hasn't started yet (wait a few seconds)"
            echo "- GitHub API rate limiting (if no token set)"
            echo "- Private repo requires GITHUB_TOKEN in .env file"
            echo ""
            echo "View manually at: https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/actions"
            echo ""
            echo "You can still monitor the workflow there and complete Device Login manually."
            exit 0
        fi
        
        log_success "Found workflow run ID: $RUN_ID"
    fi
    
    # Set RUN_URL if not already set
    if [ -z "$RUN_URL" ]; then
        RUN_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/actions/runs/${RUN_ID}"
    fi
    
    echo ""
    echo "=========================================="
    echo "📊 Deployment Progress"
    echo "=========================================="
    echo ""
    echo "Monitoring workflow progress..."
    echo ""
    echo "  Run ID: ${RUN_ID}"
    echo "  View at: ${RUN_URL}"
    echo ""
    echo "Press Ctrl+C to stop monitoring (workflow will continue running)"
    echo ""
    
    # Poll for status updates and Device Login info
    PREV_STATUS=""
    POLL_COUNT=0
    MAX_POLLS=120  # 10 minutes max (5 second intervals)
    DEVICE_LOGIN_OPENED=false
    JOB_ID=""
    
    while [ $POLL_COUNT -lt $MAX_POLLS ]; do
        STATUS=$(get_workflow_status "$RUN_ID")
        
        if [ "$STATUS" != "$PREV_STATUS" ]; then
            case "$STATUS" in
                "queued")
                    echo "⏳ Workflow queued..."
                    ;;
                "in_progress")
                    echo "🔄 Workflow running..."
                    if [ -z "$JOB_ID" ]; then
                        echo "   - Getting job information..."
                        JOB_ID=$(get_job_id "$RUN_ID")
                    fi
                    echo "   - Installing Salesforce CLI..."
                    ;;
                "completed")
                    echo ""
                    echo "✅ Deployment completed!"
                    echo ""
                    echo "View details: ${RUN_URL}"
                    exit 0
                    ;;
                "cancelled")
                    echo ""
                    echo "❌ Deployment was cancelled"
                    echo ""
                    echo "View details: ${RUN_URL}"
                    exit 1
                    ;;
                "failure")
                    echo ""
                    echo "❌ Deployment failed"
                    echo ""
                    echo "View details: ${RUN_URL}"
                    exit 1
                    ;;
            esac
            PREV_STATUS="$STATUS"
        fi
        
        # Try to get Device Login info when workflow is in progress
        if [ "$STATUS" = "in_progress" ] && [ -n "$JOB_ID" ] && [ "$DEVICE_LOGIN_OPENED" = false ]; then
            # Wait a bit for logs to be available (usually after 20-30 seconds for CLI install + device login)
            if [ $POLL_COUNT -gt 20 ]; then
                printf "\r   🔍 Checking for Device Login info... (${POLL_COUNT}s) "
                LOGIN_INFO=$(get_device_login_info "$JOB_ID")
                DEVICE_URL=$(echo "$LOGIN_INFO" | head -1)
                DEVICE_CODE=$(echo "$LOGIN_INFO" | tail -1)
                
                if [ -n "$DEVICE_URL" ] && [ -n "$DEVICE_CODE" ]; then
                    echo ""
                    echo ""
                    echo "=========================================="
                    echo "🔐 SALESFORCE LOGIN REQUIRED"
                    echo "=========================================="
                    echo ""
                    echo "Device Login URL: ${DEVICE_URL}"
                    echo "Device Code: ${DEVICE_CODE}"
                    echo ""
                    echo "Opening Salesforce login page in your browser..."
                    echo ""
                    
                    # Open the URL in browser
                    if open_browser "$DEVICE_URL"; then
                        echo "✅ Browser opened!"
                    else
                        echo "⚠️  Could not open browser automatically"
                        echo "Please visit: ${DEVICE_URL}"
                    fi
                    
                    echo ""
                    echo "📋 INSTRUCTIONS:"
                    echo "1. Enter the code above: ${DEVICE_CODE}"
                    echo "2. Log in with your Salesforce credentials"
                    echo "3. Click 'Allow' to authorize the deployment"
                    echo ""
                    echo "⏳ Waiting for authentication..."
                    echo "   (The workflow will continue automatically after you log in)"
                    echo ""
                    
                    DEVICE_LOGIN_OPENED=true
                elif [ $POLL_COUNT -gt 60 ]; then
                    # After 60 seconds, show manual instructions even if we can't extract the info
                    echo ""
                    echo ""
                    echo "=========================================="
                    echo "🔐 DEVICE LOGIN REQUIRED"
                    echo "=========================================="
                    echo ""
                    echo "Please check the GitHub Actions logs for Device Login details:"
                    echo "${RUN_URL}"
                    echo ""
                    echo "Look for:"
                    echo "- A URL (usually https://login.salesforce.com/setup/connect)"
                    echo "- An 8-digit code"
                    echo ""
                    echo "Then:"
                    echo "1. Visit the URL"
                    echo "2. Enter the code"
                    echo "3. Log in to Salesforce"
                    echo ""
                    DEVICE_LOGIN_OPENED=true
                fi
            fi
        fi
        
        # Show progress indicator
        if [ "$STATUS" = "in_progress" ]; then
            if [ "$DEVICE_LOGIN_OPENED" = true ]; then
                printf "\r   ⏳ Waiting for authentication... (${POLL_COUNT}s) "
            else
                printf "\r   ⏳ Waiting for Device Login info... (${POLL_COUNT}s) "
            fi
        fi
        
        sleep 5
        POLL_COUNT=$((POLL_COUNT + 5))
    done
    
    echo ""
    echo ""
    echo "⏱️  Polling timeout reached"
    echo "Workflow is still running. Check progress at:"
    echo "${RUN_URL}"
    echo ""
    echo "📋 If you see Device Login code in the logs:"
    echo "1. Copy the URL and code from GitHub Actions logs"
    echo "2. Visit the URL"
    echo "3. Enter the code to authenticate"
    echo "4. Deployment will continue automatically"
fi
