#!/bin/bash
# Script to trigger the GitHub Actions workflow via API

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found!"
    echo "Please ensure .env exists with GITHUB_TOKEN set"
    exit 1
fi

# Check if token is set
if [ -z "$GITHUB_TOKEN" ] || [ "$GITHUB_TOKEN" = "your_github_token_here" ]; then
    echo "Error: GITHUB_TOKEN not set in .env file!"
    exit 1
fi

# GitHub repository details
OWNER="dfelcey"
REPO="sf-demo"
WORKFLOW_FILE="deploy-with-login.yml"

# GitHub API endpoint
API_URL="https://api.github.com/repos/${OWNER}/${REPO}/actions/workflows/${WORKFLOW_FILE}/dispatches"

echo "Triggering GitHub Actions workflow: ${WORKFLOW_FILE}"
echo "Repository: ${OWNER}/${REPO}"
echo ""

# Trigger the workflow
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "${API_URL}" \
    -d '{"ref":"main"}')

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
    echo "Remember to watch the logs for the device login code!"
else
    echo "❌ Failed to trigger workflow"
    echo "HTTP Status: ${HTTP_CODE}"
    echo "Response: ${BODY}"
    exit 1
fi

