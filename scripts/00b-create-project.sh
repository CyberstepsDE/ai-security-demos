#!/usr/bin/env bash
# Creates a Foundry project under the AIServices account (needed for the
# Agents SDK - the classic Assistants API used by earlier drafts of this
# demo is retired). Also grants your own account data-plane access to it.
set -euo pipefail
source .env

SUB_ID=$(az account show --query id -o tsv)
TOKEN=$(az account get-access-token --query accessToken -o tsv)
MY_OID=$(az ad signed-in-user show --query id -o tsv)
PROJECT_NAME=demo-project

curl -sS -X PUT \
  "https://management.azure.com/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.CognitiveServices/accounts/$AIACCT/projects/$PROJECT_NAME?api-version=2025-06-01" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"location\": \"$LOC\", \"identity\": {\"type\": \"SystemAssigned\"}, \"properties\": {}}" \
  | python3 -m json.tool

az role assignment create --assignee-object-id "$MY_OID" --assignee-principal-type User \
  --role "Azure AI Developer" \
  --scope "/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.CognitiveServices/accounts/$AIACCT"

echo "PROJECT_ENDPOINT=https://${AIACCT}.services.ai.azure.com/api/projects/${PROJECT_NAME}" >> .env
echo "Wait ~30s for RBAC propagation before running 03-demo2-real-agent.py"
