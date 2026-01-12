#!/bin/bash
# Trigger script for Salesforce deployment via GitHub Actions
# This script triggers the GitHub Actions workflow which handles deployment

GITHUB_OWNER="dfelcey"
GITHUB_REPO="sf-demo"
WORKFLOW_FILE="deploy-with-login.yml"
INSTANCE_URL="${1:-https://login.salesforce.com}"

echo "=========================================="
echo "🚀 Salesforce Deployment"
echo "=========================================="
echo ""
echo "This will trigger a GitHub Actions workflow that will:"
echo "1. Install Salesforce CLI automatically"
echo "2. Use Device Login for authentication (no Connected App needed)"
echo "3. Deploy your Salesforce project"
echo ""
echo "Instance URL: $INSTANCE_URL"
echo ""

# Check if GitHub token is available (optional - workflow can run without it for public repos)
if [ -f .env ]; then
    source .env
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "⚠️  Note: GITHUB_TOKEN not set in .env file"
    echo "For private repos, you may need to set GITHUB_TOKEN"
    echo ""
fi

echo "Triggering GitHub Actions workflow..."
echo ""

# Trigger the workflow
API_URL="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/workflows/${WORKFLOW_FILE}/dispatches"

PAYLOAD=$(cat <<EOF
{
  "ref": "main",
  "inputs": {
    "sf_instance_url": "${INSTANCE_URL}"
  }
}
EOF
)

if [ -n "$GITHUB_TOKEN" ]; then
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Content-Type: application/json" \
        "${API_URL}" \
        -d "$PAYLOAD")
else
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Content-Type: application/json" \
        "${API_URL}" \
        -d "$PAYLOAD")
fi

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 204 ]; then
    echo "✅ Workflow triggered successfully!"
    echo ""
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
        
        curl -s "${headers[@]}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "$api_url" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4
    }
    
    # Function to get latest workflow run ID
    get_latest_run_id() {
        local api_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/workflows/${WORKFLOW_FILE}/runs?per_page=1"
        local headers=()
        
        if [ -n "$GITHUB_TOKEN" ]; then
            headers+=("-H" "Authorization: Bearer ${GITHUB_TOKEN}")
        fi
        
        curl -s "${headers[@]}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "$api_url" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2
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
        
        # Get logs (they come as gzip compressed)
        local logs=$(curl -s "${headers[@]}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "$api_url")
        
        # Extract Device Login URL (look for https://login.salesforce.com/setup/connect or similar)
        echo "$logs" | grep -oE 'https://[^/]+/setup/connect[^[:space:]]*' | head -1
        
        # Extract Device Login code (8 alphanumeric characters)
        echo "$logs" | grep -oE '[A-Z0-9]{8}' | head -1
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
    
    # Get the workflow run ID
    echo "Finding workflow run..."
    RUN_ID=$(get_latest_run_id)
    
    if [ -z "$RUN_ID" ]; then
        echo "⚠️  Could not find workflow run ID"
        echo "View manually at: https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/actions"
        exit 0
    fi
    
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
            # Wait a bit for logs to be available (usually after 10-15 seconds)
            if [ $POLL_COUNT -gt 15 ]; then
                echo "   - Checking for Device Login..."
                LOGIN_INFO=$(get_device_login_info "$JOB_ID")
                DEVICE_URL=$(echo "$LOGIN_INFO" | head -1)
                DEVICE_CODE=$(echo "$LOGIN_INFO" | tail -1)
                
                if [ -n "$DEVICE_URL" ] && [ -n "$DEVICE_CODE" ]; then
                    echo ""
                    echo "=========================================="
                    echo "🔐 Device Login Required"
                    echo "=========================================="
                    echo ""
                    echo "Opening Salesforce login page..."
                    echo "Device Code: ${DEVICE_CODE}"
                    echo ""
                    
                    # Open the URL in browser
                    open_browser "$DEVICE_URL"
                    
                    echo "✅ Opened: ${DEVICE_URL}"
                    echo ""
                    echo "📋 Next Steps:"
                    echo "1. Enter the code: ${DEVICE_CODE}"
                    echo "2. Log in to Salesforce"
                    echo "3. Click 'Allow' to authorize"
                    echo ""
                    echo "Waiting for authentication..."
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
    echo "❌ Failed to trigger workflow"
    echo "HTTP Status: ${HTTP_CODE}"
    echo "Response: ${BODY}"
    echo ""
    echo "If this is a private repository, you may need to set GITHUB_TOKEN in .env file"
    exit 1
fi
