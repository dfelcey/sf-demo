#!/bin/bash
# Script to trigger the GitHub Actions workflow via API
# This script should be run from the sf-demo directory
#
# Alternative: Use the web portal (no CLI required)
#   curl -L https://dfelcey.github.io/sf-demo/
#   Or open in browser: open https://dfelcey.github.io/sf-demo/

# Get the directory where this script is located (should be sf-demo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Web portal URL (update with your GitHub Pages URL)
WEB_PORTAL_URL="https://dfelcey.github.io/sf-demo/"

# Function to open web portal
open_web_portal() {
    echo "=========================================="
    echo "🌐 Opening Web Deployment Portal"
    echo "=========================================="
    echo ""
    echo "Opening: $WEB_PORTAL_URL"
    echo ""
    echo "Or use curl to access:"
    echo "  curl -L $WEB_PORTAL_URL"
    echo ""
    
    # Try to open in browser (macOS/Linux)
    if command -v open &> /dev/null; then
        open "$WEB_PORTAL_URL"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$WEB_PORTAL_URL"
    else
        echo "Please visit: $WEB_PORTAL_URL"
    fi
}

# Load environment variables from the .env file in the current directory
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "Error: .env file not found at ${ENV_FILE}!"
    echo "Please ensure .env exists in the sf-demo directory"
    exit 1
fi

# Check if token is set
if [ -z "$GITHUB_TOKEN" ] || [ "$GITHUB_TOKEN" = "your_github_token_here" ]; then
    echo "Error: GITHUB_TOKEN not set in .env file!"
    exit 1
fi

# Check if Salesforce CLI is installed
if ! command -v sf &> /dev/null; then
    echo "❌ Salesforce CLI (sf) is not installed!"
    echo ""
    echo "You have two options:"
    echo "1. Install Salesforce CLI: npm install -g @salesforce/cli"
    echo "2. Use the web portal (no CLI required):"
    echo ""
    open_web_portal
    exit 0
fi

echo "=========================================="
echo "🔐 Salesforce Org Authentication"
echo "=========================================="
echo ""

# Check for existing authenticated orgs
echo "Checking for authenticated Salesforce orgs..."
if command -v jq &> /dev/null; then
    EXISTING_ORGS=$(sf org list --json 2>/dev/null | jq -r '.result.nonScratchOrgs[]?.alias // empty' 2>/dev/null)
else
    # Fallback: check if any orgs exist (simpler check)
    EXISTING_ORGS=$(sf org list 2>/dev/null | grep -v "No orgs found" | grep -v "ALIAS" | grep -v "USERNAME" | grep -v "^$" || echo "")
fi

TARGET_ORG_ALIAS="deploy-target"

if [ -z "$EXISTING_ORGS" ]; then
    echo "No authenticated orgs found."
    echo ""
    echo "Please login to your Salesforce org:"
    echo "This will open a browser for authentication."
    echo ""
    read -p "Press Enter to continue with Salesforce login..."
    
    sf org login web --alias "$TARGET_ORG_ALIAS" --instance-url https://login.salesforce.com || {
        echo "❌ Salesforce login failed"
        exit 1
    }
    
    echo ""
    echo "✅ Successfully authenticated to Salesforce!"
else
    echo "Found authenticated org(s):"
    ORG_LIST=$(sf org list --json 2>/dev/null || echo "")
    
    if command -v jq &> /dev/null && [ -n "$ORG_LIST" ]; then
        # Display orgs with details
        echo "$ORG_LIST" | jq -r '.result.nonScratchOrgs[]? | "  - \(.alias // "unnamed") (\(.username // "no username"))"' 2>/dev/null || echo "$EXISTING_ORGS"
    else
        echo "$EXISTING_ORGS"
    fi
    echo ""
    read -p "Do you want to login to a different org? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sf org login web --alias "$TARGET_ORG_ALIAS" --instance-url https://login.salesforce.com || {
            echo "❌ Salesforce login failed"
            exit 1
        }
        echo ""
        echo "✅ Successfully authenticated to Salesforce!"
    else
        # Use the first existing org
        if command -v jq &> /dev/null && [ -n "$ORG_LIST" ]; then
            TARGET_ORG_ALIAS=$(echo "$ORG_LIST" | jq -r '.result.nonScratchOrgs[0].alias // empty' 2>/dev/null)
            if [ -z "$TARGET_ORG_ALIAS" ]; then
                TARGET_ORG_ALIAS="deploy-target"
            fi
        fi
        echo "Using existing authenticated org: $TARGET_ORG_ALIAS"
    fi
fi

echo ""
echo "=========================================="
echo "📋 Extracting Org Credentials"
echo "=========================================="
echo ""

# Extract credentials from the authenticated org
if ! command -v jq &> /dev/null; then
    echo "⚠️  Warning: jq is not installed. Cannot extract credentials automatically."
    echo "Please install jq: brew install jq (macOS) or apt-get install jq (Linux)"
    echo ""
    echo "You can manually get credentials with:"
    echo "  sf org display --target-org $TARGET_ORG_ALIAS --json | jq -r '.result.accessToken'"
    echo "  sf org display --target-org $TARGET_ORG_ALIAS --json | jq -r '.result.instanceUrl'"
    exit 1
fi

ORG_INFO=$(sf org display --target-org "$TARGET_ORG_ALIAS" --json 2>/dev/null)

if [ -z "$ORG_INFO" ]; then
    echo "❌ Failed to get org information"
    exit 1
fi

SF_ACCESS_TOKEN=$(echo "$ORG_INFO" | jq -r '.result.accessToken // empty' 2>/dev/null)
SF_INSTANCE_URL=$(echo "$ORG_INFO" | jq -r '.result.instanceUrl // empty' 2>/dev/null)
ORG_USERNAME=$(echo "$ORG_INFO" | jq -r '.result.username // "unknown"' 2>/dev/null)
ORG_ID=$(echo "$ORG_INFO" | jq -r '.result.id // "unknown"' 2>/dev/null)

if [ -z "$SF_ACCESS_TOKEN" ] || [ -z "$SF_INSTANCE_URL" ]; then
    echo "❌ Failed to extract credentials from org"
    echo "Org info: $ORG_INFO"
    exit 1
fi

echo "✅ Credentials extracted successfully!"
echo "  Org: $ORG_USERNAME"
echo "  Org ID: $ORG_ID"
echo "  Instance URL: $SF_INSTANCE_URL"
echo ""

echo ""
echo "=========================================="
echo "🚀 Triggering GitHub Actions Workflow"
echo "=========================================="
echo ""

# GitHub repository details
OWNER="dfelcey"
REPO="sf-demo"
WORKFLOW_FILE="deploy-with-login.yml"

# GitHub API endpoint
API_URL="https://api.github.com/repos/${OWNER}/${REPO}/actions/workflows/${WORKFLOW_FILE}/dispatches"

echo "Workflow: ${WORKFLOW_FILE}"
echo "Repository: ${OWNER}/${REPO}"
echo "Deploying to: $ORG_USERNAME ($ORG_ID)"
echo ""

# Prepare the workflow dispatch payload with credentials (using jq for proper JSON escaping)
if command -v jq &> /dev/null; then
    PAYLOAD=$(jq -n \
        --arg ref "main" \
        --arg token "$SF_ACCESS_TOKEN" \
        --arg url "$SF_INSTANCE_URL" \
        '{ref: $ref, inputs: {sf_access_token: $token, sf_instance_url: $url}}')
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
fi

# Trigger the workflow with credentials
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    "${API_URL}" \
    -d "$PAYLOAD")

# Extract HTTP status code (last line)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
# Extract response body (all but last line)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 204 ]; then
    echo "✅ Workflow triggered successfully!"
    echo ""
    echo "View the workflow run at:"
    echo "https://github.com/${OWNER}/${REPO}/actions"
    echo ""
    echo "The workflow will deploy to: $ORG_USERNAME"
    echo "No device login required - using provided credentials!"
else
    echo "❌ Failed to trigger workflow"
    echo "HTTP Status: ${HTTP_CODE}"
    echo "Response: ${BODY}"
    exit 1
fi

