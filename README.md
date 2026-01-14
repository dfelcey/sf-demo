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
- **Package deployment (preferred)** - automatically uses package installation if `.package-version` exists
- Direct metadata deployment (fallback) - deploys from `force-app` if no package configured
- Optional dependency package installation before deployment
- Support for package files (`.packages`)

**Deploy via package (recommended for production):**

```bash
# 1. Create a package first (one-time setup)
./create-package.sh -a devhub-org

# 2. Save the package version ID to .package-version file
echo "04tXXXXXXXXXXXXXXX" > .package-version

# 3. Deploy using package installation (faster and more reliable)
./deploy-local.sh
```

**Deploy metadata directly:**

```bash
# Deploy from force-app directory
./deploy-local.sh

# Skip package and deploy metadata directly
./deploy-local.sh --no-package

# Install dependency packages before deploying
./deploy-local.sh -p 04t000000000000,04t000000000001

# Install dependency packages from file
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

### Retrieve Agentforce Assets

**Pull Agentforce assets from a Salesforce org:**

```bash
# Pull all Agentforce assets (agents, external services, named credentials)
./pull-agentforce.sh -a my-org

# Pull to custom directory
./pull-agentforce.sh -a my-org -o agentforce-assets

# Verbose mode for debugging
./pull-agentforce.sh -a my-org --verbose

# See all options
./pull-agentforce.sh --help
```

This script retrieves:
- **AiAuthoringBundle** (Agent Script files - Next Generation Agentforce agents with .agent files)
- **Bot and BotVersion** (Agentforce agent configurations - Note: 'Agent' metadata type requires newer CLI)
- **GenAI Functions** (actions that can be added to agents)
- **GenAI Plugins** (topics/categories of actions)
- **GenAI Planner Bundles** (agent planner configurations)
- **Permission Sets** (user access permissions for agents/bots - only those assigned to current user)
- **Flows** (including flow actions)
- **External Service Registrations**
- **Named Credentials** and **External Credentials**
- **Connected Apps**
- **Custom Metadata Types**
- **Apex Classes** (including invocable actions)

### Create a Package

**Package all Agentforce assets for distribution:**

```bash
# Create an unlocked package (recommended for most use cases)
./create-package.sh -a devhub-org

# Create a managed package
./create-package.sh -a devhub-org -t Managed

# Create package with custom name and version
./create-package.sh -a devhub-org -n "My Agentforce Package" -v 2.0.0

# See all options
./create-package.sh --help
```

**Packageable Assets:**
- ✅ GenAI Functions, Plugins, and Planner Bundles
- ✅ Apex Classes (invocable actions)
- ✅ Flows
- ✅ External Service Registrations
- ✅ Named Credentials and External Credentials (metadata only, credentials must be configured separately)
- ✅ Connected Apps (metadata only)

**Note:** Named Credentials and External Credentials can be packaged, but the actual credential values (tokens, keys) are not included in the package. They must be configured separately in each org after installation.

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
├── pull-agentforce.sh                # Retrieve Agentforce assets from org
├── pull-assets.sh                    # General metadata retrieval script
├── create-package.sh                 # Create Salesforce package with assets
├── agentforce-metadata.txt           # Agentforce metadata reference
└── .packages                         # Package IDs for installation (optional)
```

### Key Files

- **`deploy-local.sh`** - Simple local deployment with package installation support
- **`trigger-deploy.sh`** - Triggers GitHub Actions deployment workflow
- **`pull-agentforce.sh`** - Convenience script to retrieve Agentforce assets from an org
- **`pull-assets.sh`** - General-purpose script to retrieve metadata from Salesforce orgs
- **`create-package.sh`** - Create Salesforce package (unlocked or managed) with all assets
- **`agentforce-metadata.txt`** - Metadata configuration file for Agentforce assets
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

### Package Deployment (Recommended)

**For optimal deployments, use package installation:**

1. **Create a package** (one-time setup):
   ```bash
   ./create-package.sh -a devhub-org
   ```

2. **Save the package version ID** to `.package-version`:
   ```bash
   echo "04tXXXXXXXXXXXXXXX" > .package-version
   ```

3. **Deploy** - the script will automatically use package installation:
   ```bash
   ./deploy-local.sh
   ```

**Benefits of package deployment:**
- ✅ Faster deployment (package installation is optimized)
- ✅ More reliable (packages are pre-validated)
- ✅ Better for production environments
- ✅ Automatic dependency management
- ✅ Version tracking

### Dependency Package Installation

Create a `.packages` file (one package ID per line) to automatically install dependency packages before deployment:

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

### CLI Installation
- **Automatic Installation**: All scripts now prompt to install Node.js and Salesforce CLI if missing
- **macOS**: Uses Homebrew if available (`brew install node`)
- **Linux**: Installs Node.js 20.x via NodeSource repository
- **Manual Installation**: If automatic installation fails, install manually:
  - Node.js: https://nodejs.org/
  - Salesforce CLI: `npm install -g @salesforce/cli@latest`
- **Update CLI**: Scripts check for updates when run with `-v` (verbose) flag

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
