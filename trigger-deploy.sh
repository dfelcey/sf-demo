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
    
    # Poll for status updates
    PREV_STATUS=""
    POLL_COUNT=0
    MAX_POLLS=120  # 10 minutes max (5 second intervals)
    
    while [ $POLL_COUNT -lt $MAX_POLLS ]; do
        STATUS=$(get_workflow_status "$RUN_ID")
        
        if [ "$STATUS" != "$PREV_STATUS" ]; then
            case "$STATUS" in
                "queued")
                    echo "⏳ Workflow queued..."
                    ;;
                "in_progress")
                    echo "🔄 Workflow running..."
                    echo "   - Installing Salesforce CLI..."
                    echo "   - Waiting for Device Login..."
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
        
        # Show progress indicator
        if [ "$STATUS" = "in_progress" ]; then
            printf "\r   ⏳ Waiting for authentication... (${POLL_COUNT}s) "
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
