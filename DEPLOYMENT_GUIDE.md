# Deployment Quick Start Guide

## Prerequisites

### 1. GitHub Personal Access Token
1. Go to: https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Name it (e.g., "sf-demo-deploy")
4. Select scope: `repo`
5. Click "Generate token"
6. Copy the token (starts with `ghp_`)

### 2. Salesforce Connected App Client ID (Required)

The **Client ID** (also called **Consumer Key**) is a unique identifier for your Salesforce Connected App. It's required for OAuth authentication.

**How to Create and Get Your Client ID:**

1. In Salesforce Setup, go to **App Manager** → **New Connected App**
2. Fill in the basic information:
   - **Connected App Name**: `GitHub Actions Deploy` (or any name you prefer)
   - **API Name**: `GitHub_Actions_Deploy` (auto-filled, can be changed)
   - **Contact Email**: Your email address
3. Enable OAuth Settings:
   - Check **Enable OAuth Settings**
   - **Callback URL**: `https://dfelcey.github.io/sf-demo/`
     - ⚠️ **Important**: This must match exactly, including the trailing slash
   - **Selected OAuth Scopes**: 
     - `Access and manage your data (api)` - Required
     - `Perform requests on your behalf at any time (refresh_token, offline_access)` - Recommended
4. Click **Save**
5. After saving, you'll see the **Consumer Key** (this is your Client ID)
   - It looks like: `3MVG9xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - Copy this value - you'll need it!

**Note**: The Consumer Secret is not needed for this flow (we use OAuth implicit flow).

## Starting a Deployment

### Method 1: Using URL Parameter (Easiest)

Visit the deployment portal with your Client ID in the URL:
```
https://dfelcey.github.io/sf-demo/?client_id=YOUR_CLIENT_ID
```

Replace `YOUR_CLIENT_ID` with your actual Consumer Key from Salesforce.

This will:
1. Immediately redirect you to Salesforce login
2. After you log in, automatically capture credentials
3. Trigger deployment automatically

### Method 2: Using the Trigger Script

1. Run: `./trigger-deploy.sh`
2. If Client ID is saved: Automatically redirects to Salesforce login
3. If Client ID not saved: Enter your Connected App Client ID once (it will be saved)
4. Select your Salesforce environment (Production or Sandbox)
5. Click "Login to Salesforce & Deploy"
6. You'll be redirected to Salesforce login
7. After login, deployment will trigger automatically

**Note**: After the first use, your Client ID is saved and the page will auto-redirect on future visits.

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

