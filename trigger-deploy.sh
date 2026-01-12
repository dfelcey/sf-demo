#!/bin/bash
# Trigger script for Salesforce deployment
# Opens web portal that will:
# 1. Prompt for GitHub token and Connected App Client ID
# 2. Automatically redirect to Salesforce login (login.salesforce.com)
# 3. Capture OAuth token after login
# 4. Trigger GitHub Actions workflow to deploy

WEB_PORTAL_URL="https://dfelcey.github.io/sf-demo/"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_FILE="${SCRIPT_DIR}/docs/index.html"

echo "=========================================="
echo "🚀 Salesforce Deployment Portal"
echo "=========================================="
echo ""
echo "This will open a web portal that will:"
echo "1. Ask for your GitHub token and Connected App Client ID"
echo "2. Redirect you to Salesforce login (login.salesforce.com)"
echo "3. Automatically capture your credentials"
echo "4. Trigger deployment to your Salesforce org"
echo ""

# Check if GitHub Pages is available
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$WEB_PORTAL_URL" 2>/dev/null)

if [ "$HTTP_CODE" = "200" ]; then
    # GitHub Pages is available, use it
    echo "Opening web portal: $WEB_PORTAL_URL"
    echo ""
    
    if command -v open &> /dev/null; then
        open "$WEB_PORTAL_URL"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$WEB_PORTAL_URL"
    else
        echo "Please visit: $WEB_PORTAL_URL"
        curl -L "$WEB_PORTAL_URL"
    fi
else
    # GitHub Pages not available, use local file
    echo "⚠️  GitHub Pages not available (HTTP $HTTP_CODE)"
    echo ""
    echo "To enable GitHub Pages:"
    echo "1. Go to: https://github.com/dfelcey/sf-demo/settings/pages"
    echo "2. Set source to: Branch 'main' / folder '/docs'"
    echo "3. Wait a few minutes for deployment"
    echo ""
    echo "Opening local file instead..."
    echo ""
    
    if [ -f "$LOCAL_FILE" ]; then
        if command -v open &> /dev/null; then
            open "$LOCAL_FILE"
        elif command -v xdg-open &> /dev/null; then
            xdg-open "$LOCAL_FILE"
        else
            echo "Please open: file://$LOCAL_FILE"
        fi
    else
        echo "❌ Local file not found: $LOCAL_FILE"
        echo "Please enable GitHub Pages or ensure docs/index.html exists"
        exit 1
    fi
fi

echo ""
echo "Follow the prompts in the browser to complete deployment."
