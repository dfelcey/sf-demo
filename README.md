# Salesforce DX Project: sf-demo

A Salesforce project with automated deployment via GitHub Actions.

## Deployment Options

### Option 1: Web Portal (No CLI Required) 🌐

Deploy from any browser without installing Salesforce CLI:

1. **Set up GitHub Pages:**
   - Go to repository Settings → Pages
   - Set source to `/docs` folder
   - Visit: `https://yourusername.github.io/sf-demo/`

2. **Create Salesforce Connected App:**
   - See [docs/README.md](docs/README.md) for detailed instructions

3. **Use the web portal:**
   - Enter your GitHub token and Connected App Client ID
   - Authenticate to Salesforce
   - Deployment triggers automatically!

See [docs/README.md](docs/README.md) for full setup instructions.

### Option 2: Local Script (CLI Required) 💻

Deploy using the local trigger script:

1. Install Salesforce CLI: `npm install -g @salesforce/cli`
2. Run: `./trigger-deploy.sh`
3. Authenticate to Salesforce when prompted
4. Script extracts credentials and triggers GitHub Actions

## Project Structure

- `force-app/` - Salesforce metadata (custom objects, classes, etc.)
- `.github/workflows/` - GitHub Actions workflow for deployment
- `docs/` - Web portal for browser-based deployment
- `trigger-deploy.sh` - Local deployment script

## How Do You Plan to Deploy Your Changes?

Do you want to deploy a set of changes, or create a self-contained application? Choose a [development model](https://developer.salesforce.com/tools/vscode/en/user-guide/development-models).

## Configure Your Salesforce DX Project

The `sfdx-project.json` file contains useful configuration information for your project. See [Salesforce DX Project Configuration](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_ws_config.htm) in the _Salesforce DX Developer Guide_ for details about this file.

## Read All About It

- [Salesforce Extensions Documentation](https://developer.salesforce.com/tools/vscode/)
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)
