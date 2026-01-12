# Salesforce Deployment Web Portal

A web-based interface for deploying Salesforce projects to any org without requiring local CLI installation.

## How It Works

1. **User visits the web page** (hosted on GitHub Pages)
2. **Enters credentials:**
   - GitHub Personal Access Token
   - Salesforce Instance URL
   - Connected App Client ID
3. **Clicks "Authenticate & Deploy"**
4. **Redirects to Salesforce OAuth login**
5. **After authentication, Salesforce redirects back with token**
6. **Web page captures token and triggers GitHub Actions workflow**
7. **GitHub Actions deploys to the authenticated org**

## Setup Instructions

### 1. Create a Salesforce Connected App

1. In Salesforce Setup, go to **App Manager** → **New Connected App**
2. Fill in:
   - **Connected App Name**: `GitHub Actions Deploy`
   - **API Name**: `GitHub_Actions_Deploy`
   - **Contact Email**: Your email
3. Enable OAuth Settings:
   - **Callback URL**: `https://yourusername.github.io/sf-demo/` (or your GitHub Pages URL)
   - **Selected OAuth Scopes**: 
     - `Access and manage your data (api)`
     - `Perform requests on your behalf at any time (refresh_token, offline_access)`
4. Save and note the **Consumer Key** (Client ID)

### 2. Configure GitHub Pages

1. Go to repository Settings → Pages
2. Set source to `/docs` folder
3. The web page will be available at: `https://yourusername.github.io/sf-demo/`

### 3. Get GitHub Personal Access Token

1. Go to https://github.com/settings/tokens
2. Generate new token (classic)
3. Select `repo` scope
4. Copy the token

### 4. Use the Portal

1. Visit your GitHub Pages URL
2. Enter:
   - GitHub token
   - Salesforce instance URL (https://login.salesforce.com or https://test.salesforce.com)
   - Connected App Client ID
3. Click "Authenticate & Deploy"
4. Complete Salesforce login
5. Deployment will trigger automatically!

## Security Notes

- GitHub token is stored in browser sessionStorage temporarily
- Salesforce access token is passed to GitHub Actions via workflow inputs
- Tokens are cleared after successful trigger
- Consider using GitHub Secrets for production use

## Benefits

✅ No local CLI installation required  
✅ Works from any device with a browser  
✅ Simple web interface  
✅ Automatic credential handling  
✅ Supports any Salesforce org  

