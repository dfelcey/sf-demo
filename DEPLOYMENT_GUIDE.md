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

3. **Authenticate:**
   - The script will open your browser for Salesforce login
   - Log in and authorize the deployment
   - Credentials are extracted automatically

4. **Watch GitHub Actions:**
   - The script shows the workflow run link
   - It automatically opens in your browser
   - Monitor deployment progress in real-time

## How It Works

1. **Trigger Script** → Authenticates you via browser login locally
2. **Extract Credentials** → Gets access token from authenticated session (no Connected App needed)
3. **Trigger Workflow** → Sends credentials to GitHub Actions workflow
4. **GitHub Actions** → Automatically installs Salesforce CLI and dependencies
5. **Authenticate** → Uses access token to authenticate to Salesforce
6. **Deployment** → Deploys your Salesforce project automatically

## Features

- ✅ **No Connected App Required** - Uses standard browser login session tokens
- ✅ **No Local CLI Required** - Everything runs in GitHub Actions (except initial auth)
- ✅ **Automatic Installation** - CLI and dependencies installed automatically
- ✅ **Simple Authentication** - Browser login, credentials handled automatically

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

### Authentication fails
- **Not logged in**: Run `sf org login web` first to authenticate locally
- **Token expired**: Access tokens expire after ~2 hours - re-run the script
- **Wrong org**: Verify the org alias exists (`sf org list`)
- **Extraction failed**: Run with `-v` flag to see detailed credential extraction logs

### CLI Installation fails
- **Node.js**: GitHub Actions runners include Node.js by default
- **Permissions**: The workflow handles installation automatically
- **Check logs**: View GitHub Actions logs for specific errors

### Deployment fails
- **Permissions**: Verify your Salesforce org has deployment permissions
- **Metadata errors**: Check that your metadata is valid
- **View logs**: Check GitHub Actions logs for detailed error messages

## Manual Workflow Trigger

**Note:** The workflow requires credentials from the trigger script. Manual triggering from GitHub UI will fail because no credentials are provided.

Always use the trigger script:
```bash
./trigger-deploy.sh
```

The script handles authentication and credential extraction automatically.

## Project Structure

- `force-app/` - Salesforce metadata to deploy
- `.github/workflows/` - GitHub Actions workflow
- `trigger-deploy.sh` - Script to trigger deployment
- `config/` - Salesforce project configuration
