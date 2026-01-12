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
    echo "View the workflow run at:"
    echo "https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/actions"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Go to GitHub Actions to watch the logs"
    echo "2. Look for a Device Login code (8 digits)"
    echo "3. Visit the URL shown in the logs"
    echo "4. Enter the code to authenticate"
    echo "5. Deployment will proceed automatically"
else
    echo "❌ Failed to trigger workflow"
    echo "HTTP Status: ${HTTP_CODE}"
    echo "Response: ${BODY}"
    echo ""
    echo "If this is a private repository, you may need to set GITHUB_TOKEN in .env file"
    exit 1
fi
