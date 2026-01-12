#!/bin/bash
# Opens web portal for Salesforce deployment
# The portal handles OAuth login and triggers GitHub Actions automatically

WEB_PORTAL_URL="https://dfelcey.github.io/sf-demo/"

# Always try to open the remote GitHub Pages URL first
echo "Opening remote deployment portal: $WEB_PORTAL_URL"
echo ""

# Try to open in browser
if command -v open &> /dev/null; then
    open "$WEB_PORTAL_URL"
elif command -v xdg-open &> /dev/null; then
    xdg-open "$WEB_PORTAL_URL"
else
    echo "Please visit: $WEB_PORTAL_URL"
    echo ""
    echo "Or use curl:"
    echo "  curl -L $WEB_PORTAL_URL"
fi

# Check if GitHub Pages is enabled
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$WEB_PORTAL_URL" 2>/dev/null)

if [ "$HTTP_CODE" != "200" ]; then
    echo ""
    echo "⚠️  GitHub Pages not enabled (HTTP $HTTP_CODE)"
    echo ""
    echo "To enable GitHub Pages:"
    echo "1. Go to: https://github.com/dfelcey/sf-demo/settings/pages"
    echo "2. Under 'Source', select:"
    echo "   - Branch: main"
    echo "   - Folder: /docs"
    echo "3. Click 'Save'"
    echo "4. Wait 1-2 minutes for deployment"
    echo ""
    echo "After enabling, the portal will be available at: $WEB_PORTAL_URL"
fi
