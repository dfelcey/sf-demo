# Deployment Quick Start Guide

## Prerequisites

### 1. GitHub Personal Access Token
1. Go to: https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Name it (e.g., "sf-demo-deploy")
4. Select scope: `repo`
5. Click "Generate token"
6. Copy the token (starts with `ghp_`)

### 2. Salesforce Connected App Client ID
1. In Salesforce Setup, go to **App Manager** → **New Connected App**
2. Fill in:
   - **Connected App Name**: `GitHub Actions Deploy`
   - **API Name**: `GitHub_Actions_Deploy`
   - **Contact Email**: Your email
3. Enable OAuth Settings:
   - **Callback URL**: `https://dfelcey.github.io/sf-demo/`
   - **Selected OAuth Scopes**: 
     - `Access and manage your data (api)`
     - `Perform requests on your behalf at any time (refresh_token, offline_access)`
4. Save and copy the **Consumer Key** (Client ID)

## Starting a Deployment

1. Run: `./trigger-deploy.sh`
2. Enter your GitHub token and Connected App Client ID
3. Select your Salesforce environment (Production or Sandbox)
4. Click "Login to Salesforce & Deploy"
5. You'll be redirected to Salesforce login
6. After login, deployment will trigger automatically

## Troubleshooting

### "GitHub token not found"
- Make sure you entered your GitHub Personal Access Token
- Check that the token has `repo` scope

### "OAuth Error"
- Verify your Connected App Client ID is correct
- Check that the Callback URL matches: `https://dfelcey.github.io/sf-demo/`
- Ensure OAuth scopes are enabled

### "Failed to trigger workflow"
- Verify your GitHub token is valid
- Check GitHub Actions permissions
- View logs at: https://github.com/dfelcey/sf-demo/actions

### Deployment fails in GitHub Actions
- Check the workflow logs
- Verify Salesforce credentials were passed correctly
- Ensure your Salesforce org has the necessary permissions

