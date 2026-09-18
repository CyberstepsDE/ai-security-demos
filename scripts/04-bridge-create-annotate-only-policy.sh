#!/usr/bin/env bash
# Bridge demo setup: create a custom content policy with jailbreak detection set
# to annotate-only (non-blocking), to show detected != blocked.
# Takes ~30-60s to propagate after creation - create this well before class.
set -euo pipefail
source .env

SUB_ID=$(az account show --query id -o tsv)
TOKEN=$(az account get-access-token --query accessToken -o tsv)

curl -sS -X PUT \
  "https://management.azure.com/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.CognitiveServices/accounts/$AIACCT/raiPolicies/annotate-only-demo?api-version=2024-10-01" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "properties": {
      "basePolicyName": "Microsoft.DefaultV2",
      "mode": "Default",
      "contentFilters": [
        {"name": "Jailbreak", "blocking": false, "enabled": true, "source": "Prompt"}
      ]
    }
  }' | python3 -m json.tool
