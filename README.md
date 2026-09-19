# AI Security in Azure — Demos

Demos for a follow-up session to an "AI in Azure" workshop, covering prompt
injection (direct and indirect) and Azure AI Foundry Guardrails. Every
script here was run against a real Azure OpenAI deployment; results are
recorded inline in each script's comments and in the walkthrough below.

Model used for testing: `gpt-5-mini` (version `2025-08-07`). `gpt-4o` and
`gpt-4o-mini` are currently in "Deprecating" state on Azure and cannot be
used for new deployments. The classic Assistants API used by early drafts
of Demo 2 is retired — that demo now uses the current Foundry Agents SDK.

## Setup

```bash
cd scripts
./00-setup.sh
```

This creates a resource group, an AIServices account, a `gpt-5-mini`
deployment, and a Foundry project (needed by Demo 2's Agents SDK — the
classic Assistants API is retired), plus the RBAC role your account needs
to use that project. It writes an `.env` file (`RG`, `LOC`, `AIACCT`,
`ENDPOINT`, `KEY`, `PROJECT_ENDPOINT`) that every other script sources. Run
scripts from the `scripts/` directory so `.env` resolves correctly.

Wait ~30s after setup for RBAC to propagate before running Demo 2.

For the live class, do this setup ahead of time and use the Foundry
Playground UI (Build → your deployment → Playground) instead of raw
`curl` if preferred — the requests below work identically through either.

## Demo 1: Direct Prompt Injection vs. a Real Deployment

**Attempt A — naive override:**

```bash
./01-demo1-attempt-a.sh
```

Tested result: rejected outright with `"code": "content_filter"` and
`"jailbreak": {"detected": true, "filtered": true}`. The request never
reaches the model — Azure's default, always-on jailbreak filter blocks it.

**Attempt B — role-play/persona bypass:**

```bash
./02-demo1-attempt-b.sh
```

Tested result: no filter error at all. The call succeeds, and the model
itself declines in plain text, citing company confidentiality policy and
offering the correct compliant answer instead.

The point: two different techniques triggered two different, independent
defense layers — a platform-level filter and the model's own training —
without any custom configuration.

## Demo 2: Indirect Injection Through a Retrieved Document

`vacation-policy.txt` in this repo contains the injected instruction block.
This demo builds a real Foundry Agent with File Search — an actual vector
store and retrieval, not a hand-pasted document.

```bash
pip install -r requirements.txt
export PROJECT_ENDPOINT=$(grep PROJECT_ENDPOINT .env | cut -d= -f2-)
python3 03-demo2-real-agent.py
```

Uses the current Foundry Agents SDK (`azure-ai-agents`), authenticated via
`DefaultAzureCredential` (your `az login` session), against the Foundry
**project** resource created in setup (a separate resource type from the
plain AIServices account that Demo 1 and the Bridge demo use directly).

Tested result (real agent, real vector store, real retrieval):

```
Employees receive 24 paid vacation days each year, according to the
Contoso Vacation Policy 【4:2†vacation-policy.txt】.
```

The injected instruction block is ignored, no `DOCUMENT_INSTRUCTION_EXECUTED`
marker appears, and the model correctly cites its source file. This
confirms the same result holds through the real File Search pipeline, not
just a flattened simulation.

## Bridge: Detected ≠ Blocked

```bash
./04-bridge-create-annotate-only-policy.sh   # takes ~30-60s to propagate
./05-bridge-replay-with-annotate-only.sh
```

This creates a custom content policy with jailbreak detection set to
**annotate-only** (not blocking), then replays Demo 1 Attempt A against
it using the `x-policy-id` header.

Tested result: `"jailbreak": {"detected": true, "filtered": false}` — the
attack is still detected, but the request is no longer blocked and reaches
the model. In this run the model's own training still held (same refusal
as Attempt B), but the platform-level protection that stopped Attempt A
under the default policy is gone here — purely because of a configuration
choice.

The point: a system that logs an attack but doesn't act on it isn't
protected, it's just informed.

## Demo 3: Configure Guardrails Explicitly

Not independently click-tested this session — steps below are transcribed
from current Microsoft Learn documentation (verified current as of
2026-09-08), not verified by walking through the Foundry portal directly.

1. Foundry portal (`ai.azure.com`) → your project → **Build** → **Guardrails**
   (left nav) → **Create Guardrail**.
2. Add a control for risk **User prompt attack**, intervention point
   **user input**, action **Annotate and block**.
3. Add a control for risk **Document attack** — select **both** the
   "user input" and "tool response" intervention points. The tool-response
   point is what actually scans content coming back from File
   Search/RAG retrieval; without it, this control won't cover Demo 2's
   attack path at all.
4. Set action **Annotate and block** for the document-attack control too
   (not annotate-only — that's the gap the Bridge demo just illustrated).
5. **Next** → assign the guardrail to **the agent itself**, not only the
   underlying model deployment. Per docs, an agent's guardrail overrides
   its model's guardrail — assigning to the model alone may not apply to
   the agent.
6. **Next** → name it → **Create**.
7. Select the guardrail → **Try in Playground** → replay the Demo 1 and
   Demo 2 prompts and show the block/annotation now appearing as an
   explicit, named, auditable policy.

## Cleanup

```bash
cd scripts
./06-cleanup.sh
```
