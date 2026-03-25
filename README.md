# MediClaw

<p align="center">
  <strong>A Sandbox for Exploring AI in Healthcare</strong>
  <br><br>
  <a href="https://github.com/vidulpanickan/NemoClaw/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-Apache_2.0-blue" alt="License"></a>
  <a href="https://github.com/vidulpanickan/NemoClaw/blob/main/SECURITY.md"><img src="https://img.shields.io/badge/Security-Report%20a%20Vulnerability-red" alt="Security"></a>
  <a href="https://github.com/vidulpanickan/NemoClaw/blob/main/docs/about/release-notes.md"><img src="https://img.shields.io/badge/status-alpha-orange" alt="Status"></a>
</p>

MediClaw is an experimental sandbox that lets anyone in healthcare — clinicians, nurses, researchers,
IT teams — explore what AI agents can do in a medical setting. It runs an [OpenClaw](https://openclaw.ai)
agent inside a sandboxed [NVIDIA OpenShell](https://github.com/NVIDIA/OpenShell) environment with
access to **30+ medical websites and APIs** (PubMed, Medscape, CDC, WHO, FDA, MDCalc, and more).

The goal is to see what's possible — both the opportunities and the risks — before AI assistants
become part of clinical workflows.

> [!CAUTION]
> **This is an experiment, not a product.** MediClaw is for exploration and learning only.
> Do not use it for patient care, clinical decisions, or any production workflow.
> AI outputs may be inaccurate, incomplete, or harmful. Always verify with authoritative sources.

---

## Table of Contents

- [Why MediClaw](#why-mediclaw)
- [Quick Start](#quick-start)
  - [Create a Cloud VM](#step-1-create-a-cloud-vm)
  - [Get an API Key](#step-2-get-an-api-key)
  - [Install](#step-3-install)
  - [Connect and Chat](#step-4-connect-and-chat)
- [Pre-Approved Medical Resources](#pre-approved-medical-resources)
- [Inference Providers](#inference-providers)
- [Isolation Model](#isolation-model)
- [Policy Presets](#policy-presets)
- [Command Reference](#command-reference)
- [Uninstall](#uninstall)
- [Learn More](#learn-more)
- [License](#license)

---

## Why MediClaw

Healthcare is one of the highest-stakes environments for AI. Before deploying AI assistants in
clinical settings, teams need a safe way to experiment — to understand what AI gets right, what
it gets wrong, and where the boundaries are.

MediClaw provides that sandbox:

- **Pre-loaded medical access** — PubMed, CDC, FDA, WHO, ClinicalTrials.gov, and 20+ more resources available out of the box
- **Deny-by-default networking** — the agent can only reach explicitly allowed domains, so you can observe exactly what it tries to access
- **Credential isolation** — API keys never enter the sandbox; auth is injected at the proxy layer
- **Cloud-only deployment** — runs on cloud VMs, not personal machines, keeping experiments separate from clinical systems
- **Operator oversight** — blocked requests surface in a real-time TUI so you can see what the agent wants to do

Built on [NVIDIA OpenShell](https://github.com/NVIDIA/OpenShell) with four isolation layers:
filesystem (Landlock), network (HTTP proxy + OPA/Rego), process (seccomp BPF), and inference routing.

---

## Quick Start

Get a sandbox running in ~10 minutes. You need a cloud VM and an LLM API key.

### Step 1: Create a Cloud VM

| Provider | Recommended Size | Notes |
|----------|-----------------|-------|
| **DigitalOcean** | 4 GB RAM / 2 vCPUs | Regular Intel ($24/mo) |
| **AWS** | t3.medium or larger | Ubuntu 22.04+ AMI |
| **GCP** | e2-medium or larger | Ubuntu 22.04+ |
| **Azure** | Standard_B2s or larger | Ubuntu 22.04+ |

> [!NOTE]
> Minimum: 4 GB RAM, 2 vCPUs, 20 GB disk. Recommended: 8 GB RAM.

### Step 2: Get an API Key

Sign up for an LLM provider. We recommend **[OpenRouter](https://openrouter.ai)** — one key gives
you access to DeepSeek, Claude, GPT, Gemini, and more.

### Step 3: Install

SSH into your VM and run:

```bash
curl -fsSL https://raw.githubusercontent.com/vidulpanickan/NemoClaw/main/scripts/bootstrap-cloud.sh | bash
```

The installer sets up Docker, Node.js, and MediClaw, then launches a 3-prompt wizard:

```text
MediClaw Setup
==============

LLM Provider:
  1) OpenRouter (recommended)
  2) NVIDIA Endpoints
  3) OpenAI
  4) Anthropic
  5) Google Gemini
Choose [1]: 1

Paste your API key below. Input is hidden for security —
you won't see characters as you type. Press Enter when done.

API key: ********

Model [deepseek/deepseek-v3.2]:
```

Setup takes ~10 minutes. When complete:

```text
──────────────────────────────────────────────────
Sandbox      medical-assistant (Landlock + seccomp + netns)
Model        deepseek/deepseek-v3.2 (OpenRouter)
──────────────────────────────────────────────────
Run:         nemoclaw medical-assistant connect
──────────────────────────────────────────────────
```

After install, activate the CLI in your current shell (one-time only):

```bash
source ~/.bashrc
```

### Step 4: Connect and Chat

```bash
nemoclaw medical-assistant connect
```

Inside the sandbox:

```bash
# Interactive chat UI
openclaw tui

# Or send a single message
openclaw agent --agent main --local \
  -m "What are the latest CDC guidelines for hypertension?" \
  --session-id test
```

Type `exit` to return to the host.

> [!TIP]
> For custom providers, local inference (Ollama, vLLM), or granular policy control, use
> `nemoclaw onboard --advanced`.

---

## Pre-Approved Medical Resources

Every sandbox has access to these domains by default. No configuration needed.

### Research & Literature

| Domain | Description |
|--------|-------------|
| `pubmed.ncbi.nlm.nih.gov` | PubMed search and articles |
| `eutils.ncbi.nlm.nih.gov` | NCBI E-utilities API |
| `api.ncbi.nlm.nih.gov` | NCBI datasets API |
| `ncbi.nlm.nih.gov` | NCBI parent site |
| `scholar.google.com` | Google Scholar |
| `www.cochranelibrary.com` | Cochrane systematic reviews |

### Clinical References & Drug Info

| Domain | Description |
|--------|-------------|
| `www.medscape.com` | Medscape clinical reference |
| `reference.medscape.com` | Medscape drug reference |
| `emedicine.medscape.com` | Medscape clinical decision support |
| `www.uptodate.com` | UpToDate (subscription required) |
| `www.dynamed.com` | DynaMed evidence-based reference |
| `online.lexi.com` | Lexicomp drug reference |
| `www.epocrates.com` | Epocrates drug interactions |
| `www.mdcalc.com` | MDCalc clinical calculators |

### Guidelines & Public Health

| Domain | Description |
|--------|-------------|
| `www.cdc.gov` | CDC guidelines and vaccination schedules |
| `www.who.int` | WHO international health guidelines |
| `www.fda.gov` | FDA drug approvals and safety alerts |
| `api.fda.gov` | FDA structured API |
| `www.ahajournals.org` | AHA/ACC cardiology guidelines |

### Government APIs

| Domain | Description |
|--------|-------------|
| `clinicaltrials.gov` | Clinical trial registry |
| `classic.clinicaltrials.gov` | Legacy trial search |
| `dailymed.nlm.nih.gov` | FDA drug label information |
| `rxnav.nlm.nih.gov` | RxNorm drug normalization API |
| `api.openfda.gov` | openFDA adverse events and recalls |
| `www.nih.gov` | NIH main site |

### Medical Coding

| Domain | Description |
|--------|-------------|
| `icd.who.int` | WHO ICD-10/ICD-11 coding API |
| `browser.ihtsdotools.org` | SNOMED CT terminology browser |
| `loinc.org` | LOINC lab/observation codes |

> [!TIP]
> Need more domains? Run `nemoclaw <name> policy-add` to apply additional presets,
> or edit the [policy YAML](nemoclaw-blueprint/policies/openclaw-sandbox.yaml) directly.

---

## Inference Providers

The agent never sees API keys or upstream endpoints. OpenShell intercepts every call at
`inference.local` and routes it through the gateway.

| Provider | Default Model | Notes |
|----------|---------------|-------|
| **OpenRouter** (default) | `deepseek/deepseek-v3.2` | Many models, one key |
| NVIDIA Endpoints | `nvidia/nemotron-3-super-120b-a12b` | Curated hosted models |
| OpenAI | `gpt-5.4` | GPT models |
| Anthropic | `claude-sonnet-4-6` | Claude models |
| Google Gemini | `gemini-2.5-flash` | Gemini models |
| Ollama | auto-detected | Local inference via `--advanced` |
| vLLM | configurable | Experimental, via `--advanced` |

---

## Isolation Model

```text
┌─────────────────────────────────────┐
│  Layer 1: NETWORK (Proxy + OPA)     │
│  Deny-by-default egress             │
│  30+ medical domains pre-approved   │
│  Binary-restricted endpoint rules   │
├─────────────────────────────────────┤
│  Layer 2: FILESYSTEM (Landlock)     │
│  /sandbox, /tmp → writable          │
│  Everything else → blocked          │
├─────────────────────────────────────┤
│  Layer 3: PROCESS (seccomp + ns)    │
│  Privilege escalation → blocked     │
│  Network namespace isolation        │
├─────────────────────────────────────┤
│  Layer 4: INFERENCE (routing)       │
│  All model calls → inference.local  │
│  Auth injected at proxy, not agent  │
└─────────────────────────────────────┘
```

When the agent tries to reach an unlisted host, OpenShell blocks the request and surfaces it in the
TUI (`openshell term`) for operator approval.

---

## Policy Presets

MediClaw ships 14 policy presets in [`nemoclaw-blueprint/policies/presets/`](nemoclaw-blueprint/policies/presets/).

| Preset | Description |
|--------|-------------|
| `medical-research` | PubMed, NCBI, Medscape |
| `clinical-references` | UpToDate, DynaMed, Lexicomp, Epocrates, MDCalc |
| `nih-resources` | ClinicalTrials.gov, DailyMed, RxNorm, openFDA, NIH |
| `clinical-guidelines` | CDC, WHO, FDA, AHA Journals |
| `medical-coding` | ICD, SNOMED CT, LOINC |
| `medical-literature` | Google Scholar, Cochrane |
| `npm` | npm and Yarn registries |
| `pypi` | Python package index |
| `docker` | Docker Hub and NVIDIA container registry |
| `huggingface` | Hugging Face Hub and inference API |
| `slack` | Slack API and webhooks |
| `telegram` | Telegram Bot API |
| `discord` | Discord API and webhooks |
| `jira` | Atlassian/Jira Cloud API |

Apply presets to a running sandbox:

```bash
nemoclaw medical-assistant policy-add
```

Or edit the base policy and re-run onboard:

```bash
# Edit nemoclaw-blueprint/policies/openclaw-sandbox.yaml
nemoclaw onboard
```

---

## Command Reference

### Host

| Command | Description |
|---------|-------------|
| `nemoclaw onboard` | 3-prompt setup (provider, key, model) |
| `nemoclaw onboard --advanced` | Full wizard with all options |
| `nemoclaw list` | List all sandboxes |
| `nemoclaw <name> connect` | Shell into sandbox |
| `nemoclaw <name> status` | Health and inference info |
| `nemoclaw <name> logs [--follow]` | Stream logs |
| `nemoclaw <name> policy-add` | Apply a policy preset |
| `nemoclaw <name> policy-list` | Show applied presets |
| `nemoclaw <name> destroy` | Delete sandbox |
| `openshell term` | Real-time monitoring TUI |

### Sandbox

| Command | Description |
|---------|-------------|
| `openclaw tui` | Interactive chat |
| `openclaw agent --agent main --local -m "..." --session-id ID` | Single message |
| `exit` | Leave sandbox |

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/vidulpanickan/NemoClaw/refs/heads/main/uninstall.sh | bash
```

| Flag | Effect |
|------|--------|
| `--yes` | Skip confirmation |
| `--keep-openshell` | Keep OpenShell binary |
| `--delete-models` | Remove Ollama models |

---

## Learn More

| Resource | Link |
|----------|------|
| Overview | [What MediClaw does](https://docs.nvidia.com/nemoclaw/latest/about/overview.html) |
| How It Works | [Plugin, blueprint, sandbox lifecycle](https://docs.nvidia.com/nemoclaw/latest/about/how-it-works.html) |
| Architecture | [Technical reference](https://docs.nvidia.com/nemoclaw/latest/reference/architecture.html) |
| Network Policies | [Egress control](https://docs.nvidia.com/nemoclaw/latest/reference/network-policies.html) |
| CLI Reference | [All commands](https://docs.nvidia.com/nemoclaw/latest/reference/commands.html) |
| Troubleshooting | [Common issues](https://docs.nvidia.com/nemoclaw/latest/reference/troubleshooting.html) |
| Community | [Discord](https://discord.gg/XFpfPv9Uvx) |

---

## License

This project is licensed under the [Apache License 2.0](LICENSE).

Built on [NVIDIA NemoClaw](https://github.com/NVIDIA/NemoClaw) and [NVIDIA OpenShell](https://github.com/NVIDIA/OpenShell).
