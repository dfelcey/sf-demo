#!/bin/bash
# Simple script to open the web-based deployment portal
# No CLI installation required - everything happens in the browser!

WEB_PORTAL_URL="https://dfelcey.github.io/sf-demo/"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_FILE="${SCRIPT_DIR}/docs/index.html"

# Check if GitHub Pages is available
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$WEB_PORTAL_URL" 2>/dev/null)

if [ "$HTTP_CODE" = "200" ]; then
    # GitHub Pages is available, use it
    if command -v open &> /dev/null; then
        open "$WEB_PORTAL_URL"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$WEB_PORTAL_URL"
    else
        echo "Opening: $WEB_PORTAL_URL"
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
