#!/usr/bin/env bash
# Provisions the Foundry/Azure OpenAI resource and model deployment used by every demo.
set -euo pipefail

RG=rg-ai-security-demo
LOC=eastus2
AIACCT=aisec-demo-$RANDOM

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

{
  echo "RG=$RG"
  echo "LOC=$LOC"
  echo "AIACCT=$AIACCT"
  echo "ENDPOINT=$ENDPOINT"
  echo "KEY=$KEY"
} > .env

echo "Wrote .env with RG, LOC, AIACCT, ENDPOINT, KEY"
