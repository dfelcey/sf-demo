#!/bin/bash
# Opens web portal for Salesforce deployment
# The portal handles OAuth login and triggers GitHub Actions automatically

WEB_PORTAL_URL="https://dfelcey.github.io/sf-demo/"
LOCAL_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/docs/index.html"

# Check if GitHub Pages is available, otherwise use local file
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$WEB_PORTAL_URL" 2>/dev/null)

if [ "$HTTP_CODE" = "200" ]; then
    # GitHub Pages available
    open "$WEB_PORTAL_URL" 2>/dev/null || \
    xdg-open "$WEB_PORTAL_URL" 2>/dev/null || \
    echo "Please visit: $WEB_PORTAL_URL"
else
    # Use local file
    if [ -f "$LOCAL_FILE" ]; then
        open "$LOCAL_FILE" 2>/dev/null || \
        xdg-open "$LOCAL_FILE" 2>/dev/null || \
        echo "Please open: file://$LOCAL_FILE"
    else
        echo "❌ Web portal not available. Enable GitHub Pages or ensure docs/index.html exists"
        exit 1
    fi
fi
