# Salesforce DX Project: sf-demo

A Salesforce project with Agentforce assets and automated deployment capabilities. Supports both local deployment and GitHub Actions-based deployment using browser-based authentication (no Connected App required).

## Quick Start

### Option 1: Simple Local Deployment (Recommended)

**Deploy directly using your local CLI:**

```bash
./deploy-local.sh my-org
```

This is the simplest approach - no GitHub Actions needed!

**Features:**
- Automatic Salesforce CLI detection
- Browser-based authentication
- Direct metadata deployment from `force-app`
- Clear prompts for org authentication

**Deploy metadata directly:**

```bash
# Deploy from force-app directory
./deploy-local.sh my-org

# Verbose mode for debugging
./deploy-local.sh -v my-org

# Deploy to a specific org alias
./deploy-local.sh my-org

# Specify instance URL and org alias
./deploy-local.sh my-sandbox https://test.salesforce.com
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

### Working with Agent Script Files (Next Generation Agents)

**Agent Script** is the foundation of Next Generation Agentforce agents. It combines natural language with programmatic expressions for handling business rules. Agent Script files (`.agent`) are stored in `AiAuthoringBundle` metadata components.

#### Pulling Agent Script Files

When you run `./pull-agentforce.sh`, Agent Script files are automatically retrieved to:
```
force-app/main/default/aiAuthoringBundles/<AgentName>/
├── <AgentName>.agent          # Agent Script file
└── <AgentName>.bundle-meta.xml # Bundle metadata
```

#### Deploying Agent Script Files

1. **Deploy the metadata:**
   ```bash
   ./deploy-local.sh target-org
   ```

2. **Publish authoring bundles** (required to activate agents):
   ```bash
   # Publish all authoring bundles
   sf agent publish --target-org target-org
   
   # Publish a specific agent
   sf agent publish --agent-name Pronto_Service_Agent --target-org target-org
   ```

**Important:** After deploying Agent Script files, you must publish the authoring bundles to activate the agents. The deployment script will remind you of this step.

#### Agent Script Workflow

Based on [Salesforce Agentforce DX documentation](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-dx-nga-author-agent.html):

1. **Create or Retrieve** - Pull existing agents from your org or create new ones
2. **Edit** - Modify Agent Script files (`.agent`) in VS Code with full syntax support
3. **Deploy** - Deploy metadata using `./deploy-local.sh <org-alias>`
4. **Publish** - Publish authoring bundles using `sf agent publish` to activate agents
5. **Test** - Test agents in your Salesforce org

#### Agent Script File Structure

Each authoring bundle contains:
- **`.agent` file** - The Agent Script source code defining agent behavior
- **`.bundle-meta.xml`** - Metadata file with bundle type (`AGENT`)

Example structure:
```
aiAuthoringBundles/
└── Pronto_Service_Agent/
    ├── Pronto_Service_Agent.agent
    └── Pronto_Service_Agent.bundle-meta.xml
```

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
- ✅ AiAuthoringBundle (Agent Script files)
- ✅ GenAI Functions, Plugins, and Planner Bundles
- ✅ Apex Classes (invocable actions)
- ✅ Flows
- ✅ External Service Registrations
- ✅ Named Credentials and External Credentials (metadata only, credentials must be configured separately)
- ✅ Connected Apps (metadata only)
- ✅ Bot and BotVersion (Legacy agents)

**Note:** 
- Named Credentials and External Credentials can be packaged, but the actual credential values (tokens, keys) are not included in the package. They must be configured separately in each org after installation.
- After installing a package containing Agent Script files, you must publish the authoring bundles using `sf agent publish --target-org <org-alias>` to activate the agents.

## How It Works

### Local Deployment (`deploy-local.sh`)

1. **Check CLI** → Verifies Salesforce CLI is installed
2. **Authenticate** → Opens browser for Salesforce login (if needed)
3. **Deploy** → Deploys metadata from `force-app/` directory

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
- ✅ **Real-time Monitoring** - Script shows deployment progress and opens workflow links
- ✅ **Agentforce Support** - Includes Agentforce assets (GenAI Functions, Plugins, Flows)

## Project Structure

```
sf-demo/
├── force-app/main/default/          # Salesforce metadata
│   ├── aiAuthoringBundles/          # Agent Script files (Next Generation agents)
│   │   └── <AgentName>/
│   │       ├── <AgentName>.agent    # Agent Script source code
│   │       └── <AgentName>.bundle-meta.xml
│   ├── bots/                        # Bot configurations (Legacy agents)
│   ├── botVersions/                 # Bot version configurations
│   ├── genAiFunctions/              # Agentforce GenAI Functions (actions)
│   ├── genAiPlugins/                # Agentforce GenAI Plugins (topics)
│   ├── genAiPlannerBundles/         # GenAI Planner Bundles
│   ├── flows/                       # Flows (including flow actions)
│   ├── externalServiceRegistrations/ # External service registrations
│   ├── externalCredentials/         # External credentials
│   ├── namedCredentials/            # Named credentials
│   ├── permissionsets/              # Permission sets (assigned to current user)
│   └── ...                          # Other metadata types
├── .github/workflows/                # GitHub Actions workflow
├── config/                           # Salesforce project configuration
├── deploy-local.sh                   # Local deployment script (recommended)
├── trigger-deploy.sh                 # GitHub Actions trigger script
├── pull-agentforce.sh                # Retrieve Agentforce assets from org
├── pull-assets.sh                    # General metadata retrieval script
├── create-package.sh                 # Create Salesforce package with assets
├── agentforce-metadata.txt           # Agentforce metadata reference
└── README.md
```

### Key Files

- **`deploy-local.sh`** - Simple local deployment from `force-app`
- **`trigger-deploy.sh`** - Triggers GitHub Actions deployment workflow
- **`pull-agentforce.sh`** - Convenience script to retrieve Agentforce assets from an org
- **`pull-assets.sh`** - General-purpose script to retrieve metadata from Salesforce orgs
- **`create-package.sh`** - Create Salesforce package (unlocked or managed) with all assets
- **`agentforce-metadata.txt`** - Metadata configuration file for Agentforce assets

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
./deploy-local.sh my-sandbox https://test.salesforce.com

# GitHub Actions deployment
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

### CLI Installation
- **Automatic Installation**: All scripts now prompt to install Node.js and Salesforce CLI if missing
- **macOS**: Uses Homebrew if available (`brew install node`)
- **Linux**: Installs Node.js 20.x via NodeSource repository
- **Manual Installation**: If automatic installation fails, install manually:
  - Node.js: https://nodejs.org/
  - Salesforce CLI: `npm install -g @salesforce/cli@latest`
- **Update CLI**: Scripts check for updates when run with `-v` (verbose) flag

### Deployment fails
- Check GitHub Actions logs for errors (if using GitHub Actions)
- Verify your Salesforce org has deployment permissions
- Ensure metadata is valid
- Check for missing dependencies or required packages
- Review deployment logs for specific component errors

### Agent Script files not activating after deployment
- **Agent Script files require publishing** after deployment to activate agents
- Run: `sf agent publish --target-org <org-alias>` after deploying
- Verify the authoring bundle was deployed successfully
- Check that the `.agent` file syntax is valid
- Ensure you have permissions to publish agents in the target org

## Salesforce DX Resources

### General Resources
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)

### Agentforce DX Resources
- [Author an Agent with Agentforce DX](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-dx-nga-author-agent.html) - Complete guide for working with Agent Script files
- [Agentforce Basics (Trailhead)](https://trailhead.salesforce.com/) - Learn about Agentforce
- [Build Enterprise-Ready Agents (Salesforce Help)](https://help.salesforce.com/) - Agentforce Builder documentation
