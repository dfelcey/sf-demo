#!/bin/bash
# Simple script to open the web-based deployment portal
# No CLI installation required - everything happens in the browser!

WEB_PORTAL_URL="https://dfelcey.github.io/sf-demo/"

# Open web portal in browser (macOS/Linux)
if command -v open &> /dev/null; then
    open "$WEB_PORTAL_URL"
elif command -v xdg-open &> /dev/null; then
    xdg-open "$WEB_PORTAL_URL"
else
    echo "Opening: $WEB_PORTAL_URL"
    echo ""
    echo "Or use curl:"
    echo "  curl -L $WEB_PORTAL_URL"
    curl -L "$WEB_PORTAL_URL"
fi
