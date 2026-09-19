#!/usr/bin/env bash
# Provisions everything used by every demo: the Foundry/Azure OpenAI resource,
# the gpt-5-mini deployment, a Foundry project (needed by the Agents SDK for
# Demo 2), and RBAC so your own account can use the project.
set -euo pipefail

RG=rg-ai-security-demo
LOC=eastus2
AIACCT=aisec-demo-$RANDOM
PROJECT_NAME=demo-project

az group create -n "$RG" -l "$LOC"

az cognitiveservices account create -n "$AIACCT" -g "$RG" -l "$LOC" \
  --kind AIServices --sku S0 --custom-domain "$AIACCT"

az cognitiveservices account deployment create \
  -g "$RG" -n "$AIACCT" \
  --deployment-name gpt-5-mini \
  --model-name gpt-5-mini \
  --model-version "2025-08-07" \
  --model-format OpenAI \
  --sku-capacity 10 \
  --sku-name GlobalStandard

ENDPOINT=$(az cognitiveservices account show -n "$AIACCT" -g "$RG" --query properties.endpoint -o tsv)
KEY=$(az cognitiveservices account keys list -n "$AIACCT" -g "$RG" --query key1 -o tsv)

# Foundry project - a separate resource type from the AIServices account
# above, required by the Agents SDK (used in Demo 2). The classic Assistants
# API (plain API key against the AIServices account) is retired.
SUB_ID=$(az account show --query id -o tsv)
TOKEN=$(az account get-access-token --query accessToken -o tsv)
MY_OID=$(az ad signed-in-user show --query id -o tsv)

curl -sS -X PUT \
  "https://management.azure.com/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.CognitiveServices/accounts/$AIACCT/projects/$PROJECT_NAME?api-version=2025-06-01" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"location\": \"$LOC\", \"identity\": {\"type\": \"SystemAssigned\"}, \"properties\": {}}" \
  > /dev/null

az role assignment create --assignee-object-id "$MY_OID" --assignee-principal-type User \
  --role "Azure AI Developer" \
  --scope "/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.CognitiveServices/accounts/$AIACCT" \
  > /dev/null

{
  echo "RG=$RG"
  echo "LOC=$LOC"
  echo "AIACCT=$AIACCT"
  echo "ENDPOINT=$ENDPOINT"
  echo "KEY=$KEY"
  echo "PROJECT_ENDPOINT=https://${AIACCT}.services.ai.azure.com/api/projects/${PROJECT_NAME}"
} > .env

echo "Wrote .env with RG, LOC, AIACCT, ENDPOINT, KEY, PROJECT_ENDPOINT"
echo "Wait ~30s for RBAC propagation before running scripts that need PROJECT_ENDPOINT (Demo 2)"
