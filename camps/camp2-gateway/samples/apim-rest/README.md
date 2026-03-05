# Sherpa MCP APIM REST Sample

This sample shows how to create the `sherpa-mcp` API in Azure API Management using Azure Resource Manager REST endpoints (via `az rest`).

## What It Creates

- APIM backend: `sherpa-mcp-backend` -> `${SHERPA_SERVER_URL}/mcp`
- MCP API: `sherpa-mcp`
- Catch-all MCP operation: `mcp-endpoint` (`* /`)
- Base API policy: routes requests to the backend
- Optional RFC 9728 PRM discovery endpoint:
  - `/.well-known/oauth-protected-resource/sherpa/mcp`

## Prerequisites

- Azure CLI signed in (`az login`)
- APIM instance already deployed
- `jq` installed

## Run

```bash
cd camps/camp2-gateway/samples/apim-rest
chmod +x create-sherpa-mcp-apim.sh

export SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export RESOURCE_GROUP=<resource-group>
export APIM_NAME=<apim-name>
export SHERPA_SERVER_URL=<https://your-sherpa-server-url>

# Optional (for PRM endpoint)
export TENANT_ID=$(az account show --query tenantId -o tsv)
export MCP_APP_CLIENT_ID=<entra-app-client-id>

./create-sherpa-mcp-apim.sh
```

## Create As `sherpa-mcp2`

```bash
export SERVER_NAME=sherpa-mcp2
export API_PATH=sherpa/mcp2
./create-sherpa-mcp-apim.sh
```

## Notes

- The script applies a minimal policy (`set-backend-service`) so traffic reaches the MCP backend.
- For production, replace the minimal policy with the Camp policy pattern (`base-oauth-contentsafety.xml`) to enforce OAuth and content safety checks.
- API version used: `2024-06-01-preview` (needed for APIM MCP resources).

## Safe Sharing Checklist

Use these files for customer sharing:

- `create-sherpa-mcp-apim.sh`
- `.env.template`
- `README.md`

Do not share these values from your environment:

- `SHERPA_SERVER_URL` (internal app URL)
- `MCP_APP_CLIENT_ID`, `TENANT_ID`, `SUBSCRIPTION_ID`
- access tokens, subscription keys, client secrets
- local `.env` files
- `.vscode/mcp.json` if it contains real URLs/keys

Recommended handoff flow:

```bash
cd camps/camp2-gateway/samples/apim-rest
cp .env.template .env
# Fill placeholders in .env, then run:
set -a && source .env && set +a
bash ./create-sherpa-mcp-apim.sh
```
