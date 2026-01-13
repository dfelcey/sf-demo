# Salesforce DX Project: sf-demo

A Salesforce project with Agentforce assets and automated deployment capabilities. Supports both local deployment and GitHub Actions-based deployment using browser-based authentication (no Connected App required).

## Quick Start

### Option 1: Simple Local Deployment (Recommended)

**Deploy directly using your local CLI:**

```bash
./deploy-local.sh
```

This is the simplest approach - no GitHub Actions needed!

**Features:**
- Automatic Salesforce CLI detection
- Browser-based authentication
- Optional package installation before deployment
- Support for package files (`.packages`)

**Install packages before deploying:**

```bash
# Install packages from command line
./deploy-local.sh -p 04t000000000000,04t000000000001

# Install packages from file
./deploy-local.sh --packages-file .packages

# Verbose mode for debugging
./deploy-local.sh -v
```

### Option 2: Deploy via GitHub Actions

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

### Local Deployment (`deploy-local.sh`)

1. **Check CLI** → Verifies Salesforce CLI is installed
2. **Authenticate** → Opens browser for Salesforce login (if needed)
3. **Install Packages** → Optionally installs packages from `.packages` file or command line
4. **Deploy** → Deploys metadata from `force-app/` directory

### GitHub Actions Deployment (`trigger-deploy.sh`)

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
- ✅ **Package Installation** - Install packages before deployment (local deployment only)
- ✅ **Real-time Monitoring** - Script shows deployment progress and opens workflow links
- ✅ **Agentforce Support** - Includes Agentforce assets (GenAI Functions, Plugins, Flows)

## Project Structure

```
sf-demo/
├── force-app/main/default/          # Salesforce metadata
│   ├── genAiFunctions/              # Agentforce GenAI Functions (actions)
│   ├── genAiPlugins/                # Agentforce GenAI Plugins (topics)
│   ├── flows/                       # Flows (including flow actions)
│   ├── externalServiceRegistrations/ # External service registrations
│   ├── externalCredentials/        # External credentials
│   ├── namedCredentials/            # Named credentials
│   └── ...                          # Other metadata types
├── .github/workflows/                # GitHub Actions workflow
├── config/                           # Salesforce project configuration
├── deploy-local.sh                   # Local deployment script (recommended)
├── trigger-deploy.sh                 # GitHub Actions trigger script
├── agentforce-metadata.txt           # Agentforce metadata reference
└── .packages                         # Package IDs for installation (optional)
```

### Key Files

- **`deploy-local.sh`** - Simple local deployment with package installation support
- **`trigger-deploy.sh`** - Triggers GitHub Actions deployment workflow
- **`agentforce-metadata.txt`** - Reference file for Agentforce metadata types
- **`.packages`** - Optional file listing package IDs to install before deployment

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
# Local deployment
./deploy-local.sh https://test.salesforce.com

# GitHub Actions deployment
./trigger-deploy.sh https://test.salesforce.com
```

### Package Installation

Create a `.packages` file (one package ID per line) to automatically install packages before deployment:

```
# Example .packages file
04t000000000000AAA
04t000000000000BBB
```

Or use the `-p` flag to specify packages directly:
```bash
./deploy-local.sh -p 04t000000000000AAA,04t000000000000BBB
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
- For local deployment, ensure Salesforce CLI is installed (`npm install -g @salesforce/cli`)

### Package installation fails
- Verify package IDs are correct (format: `04t...` for managed packages)
- Check that packages are available in your org
- Ensure you have permission to install packages
- Review package installation logs for specific errors

### Deployment fails
- Check GitHub Actions logs for errors (if using GitHub Actions)
- Verify your Salesforce org has deployment permissions
- Ensure metadata is valid
- Check for missing dependencies or required packages
- Review deployment logs for specific component errors

## Salesforce DX Resources

- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)
