# Salesforce DX Project: sf-demo

A Salesforce project with automated deployment via GitHub Actions using browser-based authentication (no Connected App required).

## Quick Start

### Deploy via GitHub Actions

1. **Run the trigger script:**
   ```bash
   ./trigger-deploy.sh
   ```
   
   Or specify a Salesforce instance URL:
   ```bash
   ./trigger-deploy.sh https://test.salesforce.com  # For sandbox
   ```

2. **Authenticate:**
   - The script will open your browser for Salesforce login
   - Log in and authorize the deployment
   - The script extracts your credentials and triggers the workflow

3. **Watch GitHub Actions:**
   - The script will show you the workflow run link
   - It will automatically open in your browser
   - Monitor the deployment progress in real-time

## How It Works

1. **Trigger Script** → Authenticates you via browser login locally
2. **Extract Credentials** → Gets access token from authenticated session
3. **Trigger Workflow** → Sends credentials to GitHub Actions workflow
4. **GitHub Actions** → Installs Salesforce CLI automatically
5. **Authenticate** → Uses access token to authenticate (no Connected App needed)
6. **Deploy** → Deploys your Salesforce project automatically

## Features

- ✅ **No Connected App Required** - Uses standard browser login session tokens
- ✅ **Automatic CLI Installation** - Detects and installs dependencies in GitHub Actions
- ✅ **Simple Authentication** - Browser login, no manual token management
- ✅ **Real-time Monitoring** - Script shows deployment progress and opens workflow links

## Project Structure

- `force-app/` - Salesforce metadata (custom objects, classes, etc.)
- `.github/workflows/` - GitHub Actions workflow for deployment
- `trigger-deploy.sh` - Script to trigger deployment
- `config/` - Salesforce project configuration

## Configuration

### Optional: GitHub Token

For private repositories, create a `.env` file:
```
GITHUB_TOKEN=ghp_your_token_here
```

Get a token from: https://github.com/settings/tokens

### Instance URL

Default: `https://login.salesforce.com` (Production)

For sandboxes, use:
```bash
./trigger-deploy.sh https://test.salesforce.com
```

## Troubleshooting

### Workflow doesn't trigger
- Check GitHub Actions permissions
- For private repos, ensure GITHUB_TOKEN is set
- View logs at: https://github.com/dfelcey/sf-demo/actions

### Authentication fails
- Make sure you're logged in to Salesforce locally (`sf org login web`)
- Verify the org alias exists (`sf org list`)
- Check that credentials were extracted successfully (run with `-v` flag)
- Access tokens expire after ~2 hours - re-run the script if needed

### Deployment fails
- Check GitHub Actions logs for errors
- Verify your Salesforce org has deployment permissions
- Ensure metadata is valid

## Salesforce DX Resources

- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)
