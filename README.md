# Salesforce DX Project: sf-demo

A Salesforce project with automated deployment via GitHub Actions using Device Login (no Connected App required).

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

2. **Watch GitHub Actions:**
   - Go to: https://github.com/dfelcey/sf-demo/actions
   - Find the running workflow
   - Watch the logs for a Device Login code

3. **Authenticate:**
   - Copy the URL and 8-digit code from the logs
   - Visit the URL in your browser
   - Enter the code and log in to Salesforce
   - Deployment will proceed automatically

## How It Works

1. **Trigger Script** → Triggers GitHub Actions workflow
2. **GitHub Actions** → Installs Salesforce CLI automatically
3. **Device Login** → Uses Salesforce Device Login (no Connected App needed)
4. **Deployment** → Deploys your Salesforce project automatically

## Features

- ✅ **No Connected App Required** - Uses Device Login
- ✅ **Automatic CLI Installation** - Detects and installs dependencies
- ✅ **Simple Authentication** - Just visit a URL and enter a code
- ✅ **No Local CLI Needed** - Everything runs in GitHub Actions

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

### Device Login fails
- Make sure you visit the URL within 10 minutes
- Verify the code matches exactly (case-sensitive)
- Check that your Salesforce org URL is correct

### Deployment fails
- Check GitHub Actions logs for errors
- Verify your Salesforce org has deployment permissions
- Ensure metadata is valid

## Salesforce DX Resources

- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)
