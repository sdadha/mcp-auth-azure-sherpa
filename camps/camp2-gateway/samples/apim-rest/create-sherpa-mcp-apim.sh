#!/bin/bash
# Create a Sherpa MCP API in Azure API Management using ARM REST calls (via az rest).
#
# Required environment variables:
#   SUBSCRIPTION_ID
#   RESOURCE_GROUP
#   APIM_NAME
#   SHERPA_SERVER_URL   (example: https://<your-sherpa-server-host>)
#
# Optional environment variables (for OAuth PRM metadata):
#   TENANT_ID
#   MCP_APP_CLIENT_ID
#
# Optional naming overrides:
#   SERVER_NAME      (default: sherpa-mcp)
#   API_PATH         (default: sherpa/mcp)
#   BACKEND_ID       (default: <SERVER_NAME>-backend)
#
# Example for a second server name:
#   export SERVER_NAME=sherpa-mcp2
#   export API_PATH=sherpa/mcp2
#
# Example:
#   export SUBSCRIPTION_ID=$(az account show --query id -o tsv)
#   export RESOURCE_GROUP=rg-camp2-dev
#   export APIM_NAME=apim-rg-camp2-dev
#   export SHERPA_SERVER_URL=https://your-sherpa-server.example.com
#   export TENANT_ID=$(az account show --query tenantId -o tsv)
#   export MCP_APP_CLIENT_ID=<entra-app-client-id>
#   ./create-sherpa-mcp-apim.sh

set -euo pipefail

API_VERSION="2024-06-01-preview"
SERVER_NAME="${SERVER_NAME:-sherpa-mcp}"
API_PATH="${API_PATH:-sherpa/mcp}"
BACKEND_ID="${BACKEND_ID:-${SERVER_NAME}-backend}"
API_ID="${API_ID:-${SERVER_NAME}}"
MCP_OPERATION_ID="mcp-endpoint"
OAUTH_API_ID="oauth-prm"
PRM_RESOURCE_PATH="${API_PATH}"
PRM_RESOURCE_PATH_ID="${PRM_RESOURCE_PATH//\//-}"
OAUTH_OPERATION_ID="get-prm-${PRM_RESOURCE_PATH_ID}"

required_vars=(SUBSCRIPTION_ID RESOURCE_GROUP APIM_NAME SHERPA_SERVER_URL)
for v in "${required_vars[@]}"; do
  if [[ -z "${!v:-}" ]]; then
    echo "Missing required env var: $v"
    exit 1
  fi
done

if [[ -z "${TENANT_ID:-}" || -z "${MCP_APP_CLIENT_ID:-}" ]]; then
  echo "Warning: TENANT_ID and/or MCP_APP_CLIENT_ID not set."
  echo "The API will still be created, but OAuth PRM metadata will be skipped."
  ENABLE_PRM="false"
else
  ENABLE_PRM="true"
fi

BASE="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.ApiManagement/service/${APIM_NAME}"

APIM_GATEWAY_URL=$(az rest --method GET \
  --uri "${BASE}?api-version=${API_VERSION}" \
  --query "properties.gatewayUrl" \
  -o tsv)

if [[ -z "${APIM_GATEWAY_URL}" ]]; then
  echo "Failed to resolve APIM gateway URL from ARM."
  exit 1
fi

echo "[1/6] Create backend '${BACKEND_ID}'"
az rest --method PUT \
  --uri "${BASE}/backends/${BACKEND_ID}?api-version=${API_VERSION}" \
  --body "$(jq -n \
    --arg url "${SHERPA_SERVER_URL}/mcp" \
    '{
      properties: {
        protocol: "http",
        url: $url,
        title: "Sherpa MCP Server",
        description: "Backend for Sherpa MCP Server"
      }
    }')" \
  --output none

echo "[2/6] Create MCP API '${API_ID}'"
az rest --method PUT \
  --uri "${BASE}/apis/${API_ID}?api-version=${API_VERSION}" \
  --body "$(jq -n --arg apiPath "${API_PATH}" --arg serverName "${SERVER_NAME}" --arg backendId "${BACKEND_ID}" '{
    properties: {
      displayName: $serverName,
      description: "MCP server passthrough for weather, trails, and gear tools",
      path: $apiPath,
      protocols: ["https"],
      subscriptionRequired: false,
      type: "mcp",
      backendId: $backendId,
      mcpProperties: {
        transportType: "streamable"
      }
    }
  }')" \
  --output none

echo "[3/6] Create MCP catch-all operation '${MCP_OPERATION_ID}'"
az rest --method PUT \
  --uri "${BASE}/apis/${API_ID}/operations/${MCP_OPERATION_ID}?api-version=${API_VERSION}" \
  --body "$(jq -n '{
    properties: {
      displayName: "MCP Endpoint",
      method: "*",
      urlTemplate: "/",
      description: "Catch-all MCP JSON-RPC endpoint"
    }
  }')" \
  --output none

echo "[4/6] Apply base API policy (route API to backend)"
# Minimal policy to route requests to the backend. Replace with OAuth + content safety as needed.
MCP_POLICY=$(cat <<'XML'
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="{{backend-id}}" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
)

MCP_POLICY=${MCP_POLICY//\{\{backend-id\}\}/${BACKEND_ID}}

az rest --method PUT \
  --uri "${BASE}/apis/${API_ID}/policies/policy?api-version=${API_VERSION}" \
  --body "$(jq -n --arg xml "${MCP_POLICY}" '{properties: {format: "rawxml", value: $xml}}')" \
  --output none

echo "[5/6] (Optional) Create OAuth PRM discovery API at root"
if [[ "${ENABLE_PRM}" == "true" ]]; then
  az rest --method PUT \
    --uri "${BASE}/apis/${OAUTH_API_ID}?api-version=${API_VERSION}" \
    --body "$(jq -n '{
      properties: {
        displayName: "OAuth Protected Resource Metadata",
        description: "RFC 9728 PRM discovery endpoint",
        path: "",
        protocols: ["https"],
        subscriptionRequired: false,
        apiType: "http"
      }
    }')" \
    --output none

  az rest --method PUT \
    --uri "${BASE}/apis/${OAUTH_API_ID}/operations/${OAUTH_OPERATION_ID}?api-version=${API_VERSION}" \
    --body "$(jq -n '{
      properties: {
        displayName: "Get PRM for MCP API",
        method: "GET",
        urlTemplate: ("/.well-known/oauth-protected-resource/" + $path),
        description: "RFC 9728 path-based PRM discovery for MCP API"
      }
    }' --arg path "${PRM_RESOURCE_PATH}")" \
    --output none

  PRM_POLICY=$(jq -n \
    --arg tenant "${TENANT_ID}" \
    --arg client "${MCP_APP_CLIENT_ID}" \
    --arg gateway "${APIM_GATEWAY_URL}" \
    '{
      issuer: ($gateway + "/"),
      authorization_endpoint: ("https://login.microsoftonline.com/" + $tenant + "/oauth2/v2.0/authorize"),
      token_endpoint: ("https://login.microsoftonline.com/" + $tenant + "/oauth2/v2.0/token"),
      jwks_uri: ("https://login.microsoftonline.com/" + $tenant + "/discovery/v2.0/keys"),
      resource: ($gateway + "/" + $path),
      scopes_supported: [("api://" + $client + "/.default")]
    }' --arg path "${PRM_RESOURCE_PATH}")

  PRM_XML="<policies><inbound><base /><return-response><set-status code=\"200\" reason=\"OK\" /><set-header name=\"Content-Type\" exists-action=\"override\"><value>application/json</value></set-header><set-body>${PRM_POLICY}</set-body></return-response></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>"

  az rest --method PUT \
    --uri "${BASE}/apis/${OAUTH_API_ID}/operations/${OAUTH_OPERATION_ID}/policies/policy?api-version=${API_VERSION}" \
    --body "$(jq -n --arg xml "${PRM_XML}" '{properties: {format: "rawxml", value: $xml}}')" \
    --output none
fi

echo "[6/6] Verify API exists"
az rest --method GET \
  --uri "${BASE}/apis/${API_ID}?api-version=${API_VERSION}" \
  --query "properties | {displayName: displayName, path: path, type: type}" \
  -o table

echo ""
echo "Done. Test endpoint: ${APIM_GATEWAY_URL}/${API_PATH}"
if [[ "${ENABLE_PRM}" == "true" ]]; then
  echo "PRM endpoint:      ${APIM_GATEWAY_URL}/.well-known/oauth-protected-resource/${PRM_RESOURCE_PATH}"
fi
