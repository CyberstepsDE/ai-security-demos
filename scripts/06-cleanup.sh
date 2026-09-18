#!/usr/bin/env bash
set -euo pipefail
source .env

az group delete -n "$RG" --yes --no-wait
