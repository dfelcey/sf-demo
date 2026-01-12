#!/bin/bash
# Opens web portal for Salesforce deployment
# The portal handles OAuth login and triggers GitHub Actions automatically

open https://dfelcey.github.io/sf-demo/ 2>/dev/null || \
xdg-open https://dfelcey.github.io/sf-demo/ 2>/dev/null || \
echo "Please visit: https://dfelcey.github.io/sf-demo/"
