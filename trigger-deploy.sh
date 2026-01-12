#!/bin/bash
# Trigger script for Salesforce deployment via GitHub Actions
# This script authenticates locally via browser login, then triggers deployment

set -e  # Exit on error (but we'll handle some errors manually)

# Configuration
GITHUB_OWNER="dfelcey"
GITHUB_REPO="sf-demo"
WORKFLOW_FILE="deploy-with-login.yml"
INSTANCE_URL="${1:-https://login.salesforce.com}"
ORG_ALIAS="${2:-deploy-target}"

# Logging function
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_debug() {
    echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
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
    echo "Please install it:"
    echo "  npm install -g @salesforce/cli"
    echo ""
    echo "Or visit: https://developer.salesforce.com/tools/salesforcecli"
    exit 1
fi

SF_VERSION=$(sf --version 2>&1)
log_success "Salesforce CLI found: $SF_VERSION"
log_debug "CLI location: $(which sf)"
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
SF_ACCESS_TOKEN=$(echo "$ORG_INFO" | jq -r '.result.accessToken // empty' 2>/dev/null)
SF_INSTANCE_URL=$(echo "$ORG_INFO" | jq -r '.result.instanceUrl // empty' 2>/dev/null)
ORG_USERNAME=$(echo "$ORG_INFO" | jq -r '.result.username // "unknown"' 2>/dev/null)
ORG_ID=$(echo "$ORG_INFO" | jq -r '.result.id // "unknown"' 2>/dev/null)

log_debug "Extracted values:"
log_debug "  Username: $ORG_USERNAME"
log_debug "  Org ID: $ORG_ID"
log_debug "  Instance URL: $SF_INSTANCE_URL"
log_debug "  Access Token: ${SF_ACCESS_TOKEN:0:20}... (length: ${#SF_ACCESS_TOKEN})"

if [ -z "$SF_ACCESS_TOKEN" ] || [ -z "$SF_INSTANCE_URL" ]; then
    log_error "Failed to extract required credentials from org"
    log_error "Access Token: ${SF_ACCESS_TOKEN:+present}${SF_ACCESS_TOKEN:-missing}"
    log_error "Instance URL: ${SF_INSTANCE_URL:+present}${SF_INSTANCE_URL:-missing}"
    log_debug "Full org info: $ORG_INFO"
    exit 1
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

# Prepare payload with credentials
log_info "Building workflow dispatch payload..."
if command -v jq &> /dev/null; then
    PAYLOAD=$(jq -n \
        --arg ref "main" \
        --arg token "$SF_ACCESS_TOKEN" \
        --arg url "$SF_INSTANCE_URL" \
        '{ref: $ref, inputs: {sf_access_token: $token, sf_instance_url: $url}}')
    log_debug "Payload created using jq (length: ${#PAYLOAD} chars)"
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
fi

log_info "Sending workflow dispatch request..."
log_debug "Using authentication: ${GITHUB_TOKEN:+Bearer token}${GITHUB_TOKEN:-none}"

if [ -n "$GITHUB_TOKEN" ]; then
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Content-Type: application/json" \
        "${API_URL}" \
        -d "$PAYLOAD" 2>&1)
    CURL_EXIT_CODE=$?
else
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Content-Type: application/json" \
    "${API_URL}" \
        -d "$PAYLOAD" 2>&1)
    CURL_EXIT_CODE=$?
fi

if [ $CURL_EXIT_CODE -ne 0 ]; then
    log_error "curl command failed with exit code: $CURL_EXIT_CODE"
    log_debug "curl response: $RESPONSE"
fi

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

log_debug "HTTP Response Code: $HTTP_CODE"
if [ -n "$BODY" ]; then
    log_debug "Response Body: $BODY"
fi

if [ "$HTTP_CODE" -eq 204 ]; then
    log_success "Workflow triggered successfully (HTTP 204)"
    echo "✅ Workflow triggered successfully!"
    echo ""
    log_info "Waiting for workflow to start..."
    echo "Waiting for workflow to start..."
    sleep 3
    
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
            "$api_url" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
        
        log_debug "Workflow status: ${status:-unknown}"
        echo "$status"
    }
    
    # Function to get latest workflow run ID
    get_latest_run_id() {
        local api_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/workflows/${WORKFLOW_FILE}/runs?per_page=1&status=in_progress"
        local headers=()
        
        if [ -n "$GITHUB_TOKEN" ]; then
            headers+=("-H" "Authorization: Bearer ${GITHUB_TOKEN}")
        fi
        
        log_debug "Fetching latest workflow run ID from: $api_url"
        
        # Try to get run ID from API response
        local response=$(curl -s "${headers[@]}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "$api_url" 2>&1)
        
        log_debug "API response length: ${#response} chars"
        
        # Try multiple ways to extract the ID
        local run_id=$(echo "$response" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
        
        # If not found, try without status filter
        if [ -z "$run_id" ]; then
            log_debug "Run ID not found with status filter, trying without filter..."
            api_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/workflows/${WORKFLOW_FILE}/runs?per_page=1"
            response=$(curl -s "${headers[@]}" \
                -H "Accept: application/vnd.github+json" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "$api_url" 2>&1)
            run_id=$(echo "$response" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
        fi
        
        # Try using jq if available
        if [ -z "$run_id" ] && command -v jq &> /dev/null; then
            log_debug "Trying jq to extract run ID..."
            run_id=$(echo "$response" | jq -r '.workflow_runs[0].id // empty' 2>/dev/null)
        fi
        
        if [ -n "$run_id" ]; then
            log_debug "Found workflow run ID: $run_id"
        else
            log_debug "Workflow run ID not found in response"
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
        
        curl -s "${headers[@]}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "$api_url" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2
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
            "$api_url" | gunzip 2>/dev/null || curl -s "${headers[@]}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "$api_url")
        
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
    
    # Get the workflow run ID (retry a few times as workflow might not appear immediately)
    log_info "Finding workflow run ID..."
    echo "Finding workflow run..."
    RUN_ID=""
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
    
    RUN_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/actions/runs/${RUN_ID}"
    echo "Workflow Run ID: ${RUN_ID}"
    echo "View at: ${RUN_URL}"
    echo ""
    echo "=========================================="
    echo "📊 Deployment Progress"
    echo "=========================================="
    echo ""
    
    # Poll for status updates and Device Login info
    PREV_STATUS=""
    POLL_COUNT=0
    MAX_POLLS=120  # 10 minutes max (5 second intervals)
    DEVICE_LOGIN_OPENED=false
    JOB_ID=""
    
    echo "Monitoring workflow progress..."
    echo ""
    
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
    
else
    log_error "Failed to trigger workflow"
    log_error "HTTP Status Code: $HTTP_CODE"
    log_error "Response Body: $BODY"
    echo "❌ Failed to trigger workflow"
    echo "HTTP Status: ${HTTP_CODE}"
    echo "Response: ${BODY}"
    echo ""
    echo "If this is a private repository, you may need to set GITHUB_TOKEN in .env file"
    exit 1
fi
