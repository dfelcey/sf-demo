#!/bin/bash
# Script to set up GitHub credentials using token from .env file

if [ ! -f .env ]; then
    echo "Error: .env file not found!"
    echo "Please copy .env.example to .env and add your GitHub token"
    exit 1
fi

# Source the .env file
source .env

if [ -z "$GITHUB_TOKEN" ] || [ "$GITHUB_TOKEN" = "your_github_token_here" ]; then
    echo "Error: GITHUB_TOKEN not set in .env file!"
    echo "Please edit .env and add your GitHub Personal Access Token"
    exit 1
fi

# Store credentials in macOS keychain
git credential-osxkeychain store <<EOF
protocol=https
host=github.com
username=dfelcey
password=$GITHUB_TOKEN
EOF

echo "GitHub credentials stored successfully!"
echo "You can now push to the repository using: git push"

