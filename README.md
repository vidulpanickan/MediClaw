# MediClaw: Secure AI Assistants for Healthcare

> Built on [NVIDIA NemoClaw](https://github.com/NVIDIA/NemoClaw) and [OpenShell](https://github.com/NVIDIA/OpenShell)

<!-- start-badges -->
[![License](https://img.shields.io/badge/License-Apache_2.0-blue)](https://github.com/vidulpanickan/NemoClaw/blob/main/LICENSE)
[![Security Policy](https://img.shields.io/badge/Security-Report%20a%20Vulnerability-red)](https://github.com/vidulpanickan/NemoClaw/blob/main/SECURITY.md)
[![Project Status](https://img.shields.io/badge/status-alpha-orange)](https://github.com/vidulpanickan/NemoClaw/blob/main/docs/about/release-notes.md)
<!-- end-badges -->

<!-- start-intro -->
MediClaw is a secure AI assistant stack purpose-built for clinicians, nurses, and healthcare teams. It runs an [OpenClaw](https://openclaw.ai) always-on agent inside a sandboxed [NVIDIA OpenShell](https://github.com/NVIDIA/OpenShell) environment where every network request, file access, and inference call is governed by policy.

Out of the box, MediClaw provides access to **30+ medical websites and APIs** including PubMed, Medscape, ClinicalTrials.gov, UpToDate, CDC, WHO, FDA, MDCalc, and more — while blocking all unauthorized network access.
<!-- end-intro -->

> **Alpha software**
>
> MediClaw is available in early preview starting March 16, 2026.
> This software is not production-ready.
> Interfaces, APIs, and behavior may change without notice.
> We welcome issues and discussion from the community while the project evolves.

---

## About

MediClaw solves a critical problem in healthcare AI: **how do you give an AI agent access to medical knowledge while preventing data leaks and unauthorized access?**

Traditional AI assistants have unrestricted network access, creating risk in clinical settings. MediClaw takes a different approach:

- **Deny-by-default networking** — the agent can only reach explicitly allowed domains
- **Pre-approved medical resources** — PubMed, Medscape, CDC, FDA, WHO, ClinicalTrials.gov, and 20+ more are allowed out of the box
- **Credential isolation** — API keys never enter the sandbox; authentication is injected at the proxy layer
- **Binary-restricted endpoints** — only `node` and `python3` can access allowed domains, preventing data exfiltration via `curl` or `wget`
- **Operator oversight** — blocked requests surface in a real-time TUI for approval or denial

MediClaw is built on NVIDIA's [OpenShell](https://github.com/NVIDIA/OpenShell) runtime (part of NVIDIA Agent Toolkit) which provides four defense-in-depth layers: filesystem (Landlock), network (HTTP proxy + OPA/Rego), process (seccomp BPF), and inference routing.

---

## Quick Start

Setup takes one install command and 3 prompts: LLM provider, API key, and model name.

### Prerequisites

| Dependency | Version |
|------------|---------|
| Linux or macOS | Ubuntu 22.04+, macOS with Colima or Docker Desktop |
| Node.js | 20 or later |
| Container runtime | Docker (Linux), Colima or Docker Desktop (macOS) |

### Install

```bash
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
```

The installer sets up Node.js if needed, then starts the onboard wizard:

```text
  MediClaw Setup
  ==============

  LLM Provider:
    1) OpenRouter (recommended)
    2) NVIDIA Endpoints
    3) OpenAI
    4) Anthropic
    5) Google Gemini
  Choose [1]:

  API key: ********

  Model [openrouter/auto]:

  Provider: OpenRouter (recommended)
  Model:    openrouter/auto
  Sandbox:  medical-assistant

  Setting up...
  ✓ Gateway started
  ✓ Sandbox created
  ✓ Medical policies applied

  ──────────────────────────────────────────────────
  Sandbox      medical-assistant (Landlock + seccomp + netns)
  ──────────────────────────────────────────────────
  Run:         nemoclaw medical-assistant connect
  ──────────────────────────────────────────────────
```

That's it. No infrastructure to configure, no policies to write.

> **For advanced users:** Run `nemoclaw onboard --advanced` for the full setup wizard with custom providers, local inference (Ollama, vLLM), NIM containers, and granular policy control.

### Chat with the Agent

```bash
# Connect to the sandbox
nemoclaw medical-assistant connect

# Inside the sandbox, open the interactive TUI
openclaw tui

# Or send a single message via CLI
openclaw agent --agent main --local -m "What are the latest guidelines for hypertension management?" --session-id test
```

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/vidulpanickan/NemoClaw/refs/heads/main/uninstall.sh | bash
```

| Flag | Effect |
|------|--------|
| `--yes` | Skip confirmation prompt |
| `--keep-openshell` | Leave OpenShell binary installed |
| `--delete-models` | Also remove Ollama models |

---

## Pre-Approved Medical Resources

Every MediClaw sandbox has access to these domains by default. No configuration needed.

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

### Government APIs (Free)

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

Need more domains? Use `nemoclaw <name> policy-add` to apply additional presets, or edit the policy YAML directly.

---

## Inference Providers

Inference requests from the agent never leave the sandbox directly. OpenShell intercepts every call and routes it through the gateway to the upstream provider. The agent only sees `inference.local` — API keys are never exposed inside the sandbox.

| Provider | Default Model | Notes |
|----------|---------------|-------|
| **OpenRouter** (default) | `openrouter/auto` | Access to many models with one key |
| NVIDIA Endpoints | `nvidia/nemotron-3-super-120b-a12b` | Curated hosted models |
| OpenAI | `gpt-5.4` | GPT models |
| Anthropic | `claude-sonnet-4-6` | Claude models |
| Google Gemini | `gemini-2.5-flash` | Gemini models |
| Ollama (local) | auto-detected | Via `--advanced` onboard |
| vLLM (local) | configurable | Via `--advanced` onboard (experimental) |

---

## Protection Layers

| Layer | What it protects | When it applies |
|-------|------------------|-----------------|
| **Network** | Blocks unauthorized outbound connections | Hot-reloadable at runtime |
| **Filesystem** | Prevents reads/writes outside `/sandbox` and `/tmp` | Locked at sandbox creation |
| **Process** | Blocks privilege escalation and dangerous syscalls | Locked at sandbox creation |
| **Inference** | Reroutes model API calls to controlled backends | Hot-reloadable at runtime |

When the agent tries to reach an unlisted host, OpenShell blocks the request and surfaces it in the TUI (`openshell term`) for operator approval.

---

## Configuring Sandbox Policy

The sandbox policy is defined in [`nemoclaw-blueprint/policies/openclaw-sandbox.yaml`](https://github.com/vidulpanickan/NemoClaw/blob/main/nemoclaw-blueprint/policies/openclaw-sandbox.yaml) and enforced by the OpenShell runtime.

| Method | How | Scope |
|--------|-----|-------|
| **Presets** | `nemoclaw <name> policy-add` | Session only; apply from built-in presets |
| **Static** | Edit `openclaw-sandbox.yaml` and re-run `nemoclaw onboard` | Persists across restarts |
| **Dynamic** | `openshell policy set <policy-file>` on a running sandbox | Session only |

### Available Presets

MediClaw ships 14 policy presets in `nemoclaw-blueprint/policies/presets/`:

| Preset | Description |
|--------|-------------|
| `medical-research` | PubMed, NCBI, Medscape |
| `clinical-references` | UpToDate, DynaMed, Lexicomp, Epocrates, MDCalc |
| `nih-resources` | ClinicalTrials.gov, DailyMed, RxNorm, openFDA, NIH |
| `clinical-guidelines` | CDC, WHO, FDA, AHA Journals |
| `medical-coding` | ICD, SNOMED CT, LOINC |
| `medical-literature` | Google Scholar, Cochrane |
| `npm` | npm and Yarn package registries |
| `pypi` | Python package index |
| `docker` | Docker Hub and NVIDIA container registry |
| `huggingface` | Hugging Face Hub and inference API |
| `slack` | Slack API and webhooks |
| `telegram` | Telegram Bot API |
| `discord` | Discord API and webhooks |
| `jira` | Atlassian/Jira Cloud API |

---

## Key Commands

### Host Commands

| Command | Description |
|---------|-------------|
| `nemoclaw onboard` | Simplified setup (3 prompts: provider, key, model) |
| `nemoclaw onboard --advanced` | Full setup wizard (custom providers, endpoints) |
| `nemoclaw list` | List all sandboxes |
| `nemoclaw <name> connect` | Shell into the sandbox |
| `nemoclaw <name> status` | Sandbox health and inference info |
| `nemoclaw <name> logs [--follow]` | Stream sandbox logs |
| `nemoclaw <name> policy-add` | Apply a network policy preset |
| `nemoclaw <name> policy-list` | List presets (applied and available) |
| `nemoclaw <name> destroy` | Stop and delete sandbox |
| `openshell term` | Launch OpenShell TUI for monitoring |

See the full [CLI reference](https://docs.nvidia.com/nemoclaw/latest/reference/commands.html) for all commands, flags, and options.

---

## Learn More

- [Overview](https://docs.nvidia.com/nemoclaw/latest/about/overview.html): What MediClaw does and how it fits together
- [How It Works](https://docs.nvidia.com/nemoclaw/latest/about/how-it-works.html): Plugin, blueprint, and sandbox lifecycle
- [Architecture](https://docs.nvidia.com/nemoclaw/latest/reference/architecture.html): Plugin structure, blueprint lifecycle, sandbox environment
- [Network Policies](https://docs.nvidia.com/nemoclaw/latest/reference/network-policies.html): Egress control and policy customization
- [CLI Commands](https://docs.nvidia.com/nemoclaw/latest/reference/commands.html): Full command reference
- [Troubleshooting](https://docs.nvidia.com/nemoclaw/latest/reference/troubleshooting.html): Common issues and resolution steps
- [Discord](https://discord.gg/XFpfPv9Uvx): Community for questions and discussion

## License

This project is licensed under the [Apache License 2.0](LICENSE).
