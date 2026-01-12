# Deployment Guide

## Quick Start

### Deploy to Salesforce

1. **Run the trigger script:**
   ```bash
   ./trigger-deploy.sh
   ```

2. **For sandbox environments:**
   ```bash
   ./trigger-deploy.sh https://test.salesforce.com
   ```

3. **Watch GitHub Actions:**
   - Go to: https://github.com/dfelcey/sf-demo/actions
   - Find the running workflow
   - Watch the logs for a Device Login code

4. **Authenticate:**
   - Copy the URL and 8-digit code from the logs
   - Visit the URL in your browser
   - Enter the code and log in to Salesforce
   - Deployment will proceed automatically

## How It Works

1. **Trigger Script** → Calls GitHub Actions API to start workflow
2. **GitHub Actions** → Automatically installs Salesforce CLI and dependencies
3. **Device Login** → Uses Salesforce Device Login (no Connected App needed)
4. **Deployment** → Deploys your Salesforce project automatically

## Features

- ✅ **No Connected App Required** - Uses Device Login
- ✅ **No Local CLI Required** - Everything runs in GitHub Actions
- ✅ **Automatic Installation** - CLI and dependencies installed automatically
- ✅ **Simple Authentication** - Just visit a URL and enter a code

## Configuration

### Optional: GitHub Token

For private repositories, create a `.env` file:
```
GITHUB_TOKEN=ghp_your_token_here
```

Get a token from: https://github.com/settings/tokens
- Select scope: `repo`
- Copy the token (starts with `ghp_`)

### Instance URLs

- **Production**: `https://login.salesforce.com` (default)
- **Sandbox**: `https://test.salesforce.com`
- **Custom**: Any Salesforce instance URL

## Troubleshooting

### Workflow doesn't trigger
- **For private repos**: Set `GITHUB_TOKEN` in `.env` file
- **Check permissions**: Ensure GitHub Actions is enabled
- **View logs**: Go to https://github.com/dfelcey/sf-demo/actions

### Device Login fails
- **Timeout**: Make sure you visit the URL within 10 minutes
- **Code mismatch**: Verify the code matches exactly (case-sensitive)
- **Wrong URL**: Check that your Salesforce org URL is correct
- **Network issues**: Ensure you can access Salesforce login page

### CLI Installation fails
- **Node.js**: GitHub Actions runners include Node.js by default
- **Permissions**: The workflow handles installation automatically
- **Check logs**: View GitHub Actions logs for specific errors

### Deployment fails
- **Permissions**: Verify your Salesforce org has deployment permissions
- **Metadata errors**: Check that your metadata is valid
- **View logs**: Check GitHub Actions logs for detailed error messages

## Manual Workflow Trigger

You can also trigger the workflow manually from GitHub:

1. Go to: https://github.com/dfelcey/sf-demo/actions
2. Select "Salesforce Deployment via Device Login"
3. Click "Run workflow"
4. Optionally set the instance URL
5. Click "Run workflow"
6. Follow the Device Login steps

## Project Structure

- `force-app/` - Salesforce metadata to deploy
- `.github/workflows/` - GitHub Actions workflow
- `trigger-deploy.sh` - Script to trigger deployment
- `config/` - Salesforce project configuration
