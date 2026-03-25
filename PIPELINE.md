# PIPELINE.md — How MediClaw Works End-to-End

This document traces the complete pipeline from installation to a running sandboxed OpenClaw agent, with links to every script and source file involved.

---

## Flow Diagram

```text
┌─────────────────────────────────────────────────────────────────────────┐
│  INSTALL                                                                │
│  curl ... | bash  ──→  install.sh                                       │
│    ① Ensure Node.js ≥20                                                 │
│    ② Clone repo, build plugin, link CLI globally                        │
│    ③ Run nemoclaw onboard                                               │
└────────────────────────────┬────────────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  ONBOARD (7-step wizard)  ──→  bin/lib/onboard.js                       │
│                                                                         │
│  ① Preflight ─────→ Docker? OpenShell? Ports? GPU?                      │
│  ② Inference ─────→ Pick provider + model, validate credentials         │
│  ③ Gateway ───────→ openshell gateway start --name nemoclaw             │
│  ④ Sandbox ───────→ Build Dockerfile → openshell sandbox create         │
│  ⑤ Provider ──────→ openshell provider create + inference set           │
│  ⑥ Config ────────→ Write ~/.nemoclaw/config.json inside sandbox        │
│  ⑦ Policies ──────→ openshell policy set (auto-detect presets)          │
└────────────────────────────┬────────────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  SANDBOX STARTUP  ──→  scripts/nemoclaw-start.sh (entrypoint)           │
│                                                                         │
│  ① Verify config hash (SHA-256 pinned at build time)                    │
│  ② Write auth profile for agent                                         │
│  ③ Start OpenClaw gateway as 'gateway' user (gosu)                      │
│  ④ Start auto-pair watcher (approves device connections)                │
│  ⑤ Print dashboard URLs with auth token                                 │
└────────────────────────────┬────────────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  PLUGIN LOADS  ──→  nemoclaw/src/index.ts                               │
│                                                                         │
│  register(api)                                                          │
│    ├─ registerCommand("/nemoclaw")  → slash.ts handles status/eject     │
│    ├─ registerProvider("inference") → routes to inference.local          │
│    └─ loadOnboardConfig()           → reads ~/.nemoclaw/config.json     │
└────────────────────────────┬────────────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  AGENT RUNNING — INFERENCE ROUTING                                      │
│                                                                         │
│  Agent code                                                             │
│    → inference.local/v1/chat/completions                                │
│      → OpenShell HTTP CONNECT proxy (injects auth header)               │
│        → OpenShell gateway (host-side)                                  │
│          → Upstream provider (NVIDIA / OpenAI / Ollama / etc.)          │
│            → Response flows back to agent                               │
│                                                                         │
│  Agent NEVER sees API keys or upstream endpoints directly.              │
└─────────────────────────────────────────────────────────────────────────┘
```text

---

## File Map — Every Script and What It Does

### CLI Entry & Dispatch

| File | Summary |
|------|---------|
| [`bin/nemoclaw.js`](bin/nemoclaw.js) | Main CLI entry point. Routes all commands: `onboard`, `list`, `deploy`, `start`, `stop`, `status`, `debug`, `uninstall`, and sandbox-scoped commands (`<name> connect\|status\|logs\|destroy\|policy-add\|policy-list`). |

### CLI Library Modules (`bin/lib/`)

Each module handles one concern. The onboard wizard orchestrates them in sequence.

| File | Summary |
|------|---------|
| [`bin/lib/onboard.js`](bin/lib/onboard.js) | 7-step onboard wizard. Goes from zero to a running sandbox. Supports `--non-interactive` mode via env vars. The main orchestrator that calls everything below. |
| [`bin/lib/runner.js`](bin/lib/runner.js) | Shell command executor. Provides `run()`, `runCapture()`, `shellQuote()`. Detects `DOCKER_HOST`, propagates exit codes, inherits stdio. |
| [`bin/lib/credentials.js`](bin/lib/credentials.js) | Reads/writes API keys at `~/.nemoclaw/credentials.json` (mode 600). Prompts user for keys during onboard. |
| [`bin/lib/preflight.js`](bin/lib/preflight.js) | Pre-flight checks: port availability, Docker running, dependency validation, platform-specific checks. |
| [`bin/lib/inference-config.js`](bin/lib/inference-config.js) | Inference provider selection logic. Defines cloud model catalogs (Nemotron, GPT, Claude, Gemini), route profiles, credential env var mappings. |
| [`bin/lib/local-inference.js`](bin/lib/local-inference.js) | Local inference management. Handles Ollama and vLLM base URLs, model size validation (32GB+ for large models), host gateway routing. |
| [`bin/lib/nim.js`](bin/lib/nim.js) | NVIDIA NIM container lifecycle: pull image, start/stop container, health checks. Reads model→image mappings from `bin/lib/nim-images.json`. |
| [`bin/lib/policies.js`](bin/lib/policies.js) | Policy preset management. Lists presets from `nemoclaw-blueprint/policies/presets/`, merges and applies them via `openshell policy set`. |
| [`bin/lib/registry.js`](bin/lib/registry.js) | Multi-sandbox registry at `~/.nemoclaw/sandboxes.json`. Tracks sandbox names, models, providers, policies, NIM containers. |
| [`bin/lib/platform.js`](bin/lib/platform.js) | Platform detection: Windows/macOS/Linux, WSL, Docker host socket routing. |
| [`bin/lib/resolve-openshell.js`](bin/lib/resolve-openshell.js) | Finds the `openshell` binary with security checks. Validates absolute paths to prevent alias injection. Falls back to standard install locations. |

### TypeScript Plugin (`nemoclaw/src/`)

Runs inside the sandbox as an OpenClaw plugin. Handles chat commands and inference routing.

| File | Summary |
|------|---------|
| [`nemoclaw/src/index.ts`](nemoclaw/src/index.ts) | Plugin entry point. Called by OpenClaw host via `register(api)`. Registers the `/nemoclaw` slash command, the `inference` provider, and loads onboard config. |
| [`nemoclaw/src/commands/slash.ts`](nemoclaw/src/commands/slash.ts) | Slash command handler. `/nemoclaw status` shows state, `/nemoclaw eject` shows rollback instructions. |
| [`nemoclaw/src/commands/migration-state.ts`](nemoclaw/src/commands/migration-state.ts) | Migration state tracking for `~/.openclaw` directory. Handles tar snapshots, extraction, rollback and cutover operations. |
| [`nemoclaw/src/blueprint/runner.ts`](nemoclaw/src/blueprint/runner.ts) | Blueprint lifecycle orchestrator. Actions: `plan`, `apply`, `status`, `rollback`. Invokes the Python blueprint as a subprocess. Uses PROGRESS/RUN_ID protocol for output. |
| [`nemoclaw/src/blueprint/state.ts`](nemoclaw/src/blueprint/state.ts) | Persists deployment state to `~/.nemoclaw/state/nemoclaw.json`. Tracks lastRunId, lastAction, blueprintVersion, sandboxName, timestamps. |
| [`nemoclaw/src/blueprint/snapshot.ts`](nemoclaw/src/blueprint/snapshot.ts) | Migration snapshot/restore. Captures and restores `.openclaw` config, workspace, extensions, skills between host and sandbox. |
| [`nemoclaw/src/blueprint/ssrf.ts`](nemoclaw/src/blueprint/ssrf.ts) | SSRF detection. Validates URLs against private IP ranges (127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, etc.) to prevent server-side request forgery. |
| [`nemoclaw/src/onboard/config.ts`](nemoclaw/src/onboard/config.ts) | Onboard config schema. Defines `EndpointType` enum (build, openai, anthropic, gemini, ncp, nim-local, vllm, ollama, custom). Loads/describes `~/.nemoclaw/config.json`. |

### Host Scripts (`scripts/`)

Setup, utilities, and services that run on the host machine.

| File | Summary |
|------|---------|
| [`install.sh`](install.sh) | Curl-pipe-bash installer. Three steps: ensure Node.js, clone+build+link MediClaw CLI, run `nemoclaw onboard`. |
| [`uninstall.sh`](uninstall.sh) | Removes sandboxes, gateway, providers, Docker images, state dirs, npm package. Preserves Docker/Node.js/Ollama. |
| [`scripts/nemoclaw-start.sh`](scripts/nemoclaw-start.sh) | Sandbox container entrypoint. Verifies config integrity, starts OpenClaw gateway as `gateway` user with privilege separation, runs auto-pair watcher, prints dashboard URLs. |
| [`scripts/install-openshell.sh`](scripts/install-openshell.sh) | Downloads and installs the `openshell` binary. Detects OS/arch, verifies checksums. |
| [`scripts/setup.sh`](scripts/setup.sh) | Host setup after install. Starts OpenShell gateway, fixes CoreDNS, creates inference providers. |
| [`scripts/start-services.sh`](scripts/start-services.sh) | Starts auxiliary services: Telegram bridge and cloudflared tunnel. Supports `--status` and `--stop` flags. |
| [`scripts/telegram-bridge.js`](scripts/telegram-bridge.js) | Node.js Telegram bot that forwards messages to/from the sandboxed OpenClaw agent. Requires `TELEGRAM_BOT_TOKEN`. |
| [`scripts/setup-spark.sh`](scripts/setup-spark.sh) | DGX Spark device setup. Adds user to docker group, sets `cgroupns=host` in daemon.json for k3s-in-Docker compatibility. |
| [`scripts/fix-coredns.sh`](scripts/fix-coredns.sh) | Fixes CoreDNS CrashLoop on Colima. Patches DNS forwarding to use the container gateway IP instead of 127.0.0.11. |
| [`scripts/debug.sh`](scripts/debug.sh) | Collects diagnostic info for bug reports. Supports `--quick` (stdout) and `--output FILE` (tarball). |
| [`scripts/backup-workspace.sh`](scripts/backup-workspace.sh) | Backs up OpenClaw workspace files (SOUL.md, USER.md, IDENTITY.md, AGENTS.md, MEMORY.md) to `~/.nemoclaw/backups/`. |
| [`scripts/brev-setup.sh`](scripts/brev-setup.sh) | Brev VM bootstrap. Installs Docker, NVIDIA Container Toolkit, OpenShell CLI on a fresh VM. |
| [`scripts/docs-to-skills.py`](scripts/docs-to-skills.py) | Converts `docs/` Markdown pages into agent skills under `.agents/skills/`. Auto-generates SKILL.md + references/. |
| [`scripts/check-spdx-headers.sh`](scripts/check-spdx-headers.sh) | Checks and auto-inserts Apache-2.0 SPDX license headers on source files. |
| [`scripts/check-coverage-ratchet.sh`](scripts/check-coverage-ratchet.sh) | Coverage ratcheting. Fails CI if test coverage drops below `ci/coverage-threshold.json` thresholds. |
| [`scripts/smoke-macos-install.sh`](scripts/smoke-macos-install.sh) | End-to-end smoke test: full install → verify logs → uninstall → verify cleanup. |
| [`scripts/test-inference.sh`](scripts/test-inference.sh) | Tests inference.local routing through OpenShell to NVIDIA cloud backend. |
| [`scripts/test-inference-local.sh`](scripts/test-inference-local.sh) | Tests inference.local routing through OpenShell to local vLLM backend. |
| [`scripts/walkthrough.sh`](scripts/walkthrough.sh) | Demo script. Split-screen OpenClaw chat + OpenShell TUI showing policy enforcement. |
| [`scripts/update-docker-pin.sh`](scripts/update-docker-pin.sh) | Updates pinned SHA-256 digest for `node:22-slim` base image in Dockerfile. |

### Container Build & Config

| File | Summary |
|------|---------|
| [`Dockerfile`](Dockerfile) | Two-stage build. Stage 1: compile TypeScript plugin. Stage 2: runtime with Python, gosu, OpenClaw. Generates immutable `openclaw.json`, creates gateway/sandbox users, pins config hash. |
| [`nemoclaw/openclaw.plugin.json`](nemoclaw/openclaw.plugin.json) | OpenClaw plugin manifest. Declares plugin ID `nemoclaw`, config schema (blueprintVersion, sandboxName, inferenceProvider). |
| [`nemoclaw-blueprint/blueprint.yaml`](nemoclaw-blueprint/blueprint.yaml) | Blueprint spec. Defines version, profiles (default/ncp/nim-local/vllm), sandbox image, inference endpoints, policy additions. |
| [`nemoclaw-blueprint/policies/openclaw-sandbox.yaml`](nemoclaw-blueprint/policies/openclaw-sandbox.yaml) | Default deny-by-default security policy. Filesystem (Landlock), network (binary-restricted endpoint rules), process isolation. |

---

## Detailed Flow: What Happens When You Run `nemoclaw onboard`

### Phase 1: Preflight

```text
bin/nemoclaw.js  →  onboard()  →  require('./lib/onboard')
                                        │
                                        ├─ bin/lib/preflight.js    ← Port checks
                                        ├─ bin/lib/runner.js       ← docker info
                                        ├─ bin/lib/resolve-openshell.js  ← Find openshell binary
                                        │     └─ scripts/install-openshell.sh  ← Install if missing
                                        ├─ bin/lib/nim.js          ← GPU detection (nvidia-smi)
                                        └─ bin/lib/runner.js       ← openshell gateway destroy (cleanup stale)
```text

**What happens:** Checks that Docker is running, OpenShell CLI is installed (installs it if not), ports 8080/18789 are free, and detects GPU type. Tears down any stale gateway.

### Phase 2: Inference Provider Selection

```text
bin/lib/onboard.js  →  setupNim(gpu)
    │
    ├─ bin/lib/inference-config.js   ← Provider catalog + model lists
    ├─ bin/lib/credentials.js        ← Prompt for API key, store at ~/.nemoclaw/credentials.json
    ├─ bin/lib/local-inference.js     ← Ollama/vLLM base URL + model validation
    └─ bin/lib/nim.js                ← NIM container pull/start (if GPU + experimental)
```text

**What happens:** Shows provider menu (NVIDIA/OpenAI/Anthropic/Gemini/Ollama/etc.), prompts for API key, validates by probing the endpoint. For local providers, pulls the model and starts the service.

### Phase 3: Gateway

```text
bin/lib/onboard.js  →  startGateway()
    │
    ├─ bin/lib/runner.js     ← openshell gateway start --name nemoclaw
    ├─ scripts/fix-coredns.sh  ← Patch DNS if Colima detected
    └─ bin/lib/runner.js     ← openshell gateway select nemoclaw
```text

**What happens:** Starts a k3s-in-Docker gateway named `nemoclaw`. Patches CoreDNS on Colima to prevent DNS resolution failures. Sets as default gateway.

### Phase 4: Sandbox Creation

```text
bin/lib/onboard.js  →  createSandbox()
    │
    ├─ Stage build context (temp dir)
    │     ├─ Dockerfile            ← Patched with ARGs (model, provider, inference URL)
    │     ├─ nemoclaw/             ← Plugin source
    │     ├─ nemoclaw-blueprint/   ← Blueprint + policies
    │     └─ scripts/              ← Including nemoclaw-start.sh (entrypoint)
    │
    ├─ bin/lib/runner.js  ← openshell sandbox create --from Dockerfile --policy ...
    │     └─ Dockerfile builds:
    │           Stage 1: npm install + tsc → dist/
    │           Stage 2: Install OpenClaw, generate openclaw.json, pin hash, lock perms
    │
    ├─ Poll for Ready state (openshell sandbox list, max 60s)
    ├─ bin/lib/runner.js  ← openshell forward start 18789
    └─ bin/lib/registry.js  ← Register in ~/.nemoclaw/sandboxes.json
```text

**What happens:** Copies project files into a temp dir, patches the Dockerfile with runtime config (model name, provider key, inference URL), builds the container image, creates the sandbox with the security policy applied, waits for it to start, forwards the dashboard port.

### Phase 5: Inference Provider Registration

```text
bin/lib/onboard.js  →  setupInference()
    │
    ├─ bin/lib/runner.js  ← openshell provider create --name ... --credential ...
    └─ bin/lib/runner.js  ← openshell inference set --provider ... --model ...
```text

**What happens:** Registers the inference provider in OpenShell's server-side config. The credential (API key) is stored by OpenShell — the sandbox never sees it directly. OpenShell's proxy injects auth headers at runtime.

### Phase 6: Plugin Config Inside Sandbox

```text
bin/lib/onboard.js  →  setupOpenclaw()
    │
    ├─ bin/lib/inference-config.js  ← getProviderSelectionConfig()
    └─ bin/lib/runner.js  ← openshell sandbox connect <name> < write_config_script
          └─ Writes ~/.nemoclaw/config.json inside sandbox
                └─ Read by nemoclaw/src/onboard/config.ts at plugin startup
```text

**What happens:** Generates an onboard config (provider, model, endpoint, profile, timestamp) and writes it inside the sandbox. The plugin reads this config when OpenClaw loads it.

### Phase 7: Policy Application

```text
bin/lib/onboard.js  →  setupPolicies()
    │
    ├─ Auto-detect from env: TELEGRAM_BOT_TOKEN → telegram preset
    │                        SLACK_BOT_TOKEN → slack preset
    │                        DISCORD_BOT_TOKEN → discord preset
    │
    └─ bin/lib/policies.js  ← openshell policy set --preset <name> (×N)
         └─ Presets from: nemoclaw-blueprint/policies/presets/
```text

**What happens:** Detects which services the user wants (based on env vars) and applies the corresponding network policy presets. These open specific endpoints in the deny-by-default firewall.

---

## Detailed Flow: Sandbox Container Boot

When the sandbox pod starts, the container runs `scripts/nemoclaw-start.sh` as root:

```text
scripts/nemoclaw-start.sh (PID 1, root)
    │
    ├─ verify_config_integrity()
    │     └─ sha256sum -c /sandbox/.openclaw/.config-hash
    │        (fails hard if openclaw.json was tampered with)
    │
    ├─ Write auth profile
    │     └─ ~/.openclaw/agents/main/agent/auth-profiles.json
    │        (NVIDIA_API_KEY if set)
    │
    ├─ gosu gateway openclaw gateway run &
    │     └─ OpenClaw gateway process (cannot be killed by sandbox user)
    │        Loads /sandbox/.openclaw/openclaw.json (immutable, root:root, mode 444)
    │        Serves on port 18789
    │
    ├─ start_auto_pair()
    │     └─ Python script polls openclaw devices list
    │        Auto-approves pairing requests (timeout 600s)
    │
    └─ print_dashboard_urls()
          └─ Extracts auth token from openclaw.json
             Prints: http://127.0.0.1:18789/#token=<token>
```text

Then the OpenClaw gateway loads the MediClaw plugin:

```text
nemoclaw/src/index.ts  →  register(api: OpenClawPluginApi)
    │
    ├─ api.registerCommand("nemoclaw")
    │     └─ nemoclaw/src/commands/slash.ts  →  handleSlashCommand()
    │           ├─ /nemoclaw status  → loads state from ~/.nemoclaw/state/
    │           └─ /nemoclaw eject   → shows rollback instructions
    │
    ├─ api.registerProvider("inference")
    │     └─ Routes to https://inference.local/v1
    │        Aliases: "inference-local", "nemoclaw"
    │        Models loaded from nemoclaw/src/onboard/config.ts
    │
    └─ loadOnboardConfig()
          └─ Reads ~/.nemoclaw/config.json (written during onboard step 6)
```text

---

## Inference Routing Detail

```text
Agent code calls model API
    │
    ▼
https://inference.local/v1/chat/completions
    │
    ▼  (DNS resolves to sandbox-local proxy)
OpenShell HTTP CONNECT proxy (in-pod)
    │  ← Enforces network policy (OPA/Rego)
    │  ← Injects Authorization header from stored credential
    ▼
OpenShell gateway (host-side, k3s)
    │
    ▼
Upstream provider endpoint
    ├─ NVIDIA: integrate.api.nvidia.com/v1
    ├─ OpenAI: api.openai.com/v1
    ├─ Anthropic: api.anthropic.com/v1
    ├─ Ollama: localhost:11434/v1
    └─ vLLM: localhost:8000/v1
```text

The agent only ever sees `inference.local`. API keys are never exposed inside the sandbox.

---

## Security Layers

```text
┌─────────────────────────────────────┐
│  Layer 1: FILESYSTEM (Landlock)     │
│  /sandbox/.openclaw/ → read-only    │
│  /sandbox, /tmp → writable          │
│  Everything else → blocked          │
├─────────────────────────────────────┤
│  Layer 2: NETWORK (Proxy + OPA)     │
│  Deny-by-default egress             │
│  Binary-restricted endpoint rules   │
│  Unlisted hosts → blocked + TUI     │
├─────────────────────────────────────┤
│  Layer 3: PROCESS (seccomp + ns)    │
│  Privilege escalation → blocked     │
│  Network namespace isolation        │
│  Gateway user ≠ sandbox user        │
├─────────────────────────────────────┤
│  Layer 4: INFERENCE (routing)       │
│  All model calls → inference.local  │
│  Auth injected at proxy, not agent  │
│  Hot-reloadable provider config     │
└─────────────────────────────────────┘
```text

---

## State & Config Files

| Path | Written by | Read by | Purpose |
|------|-----------|---------|---------|
| `~/.nemoclaw/config.json` | [`bin/lib/onboard.js`](bin/lib/onboard.js) | [`nemoclaw/src/onboard/config.ts`](nemoclaw/src/onboard/config.ts) | Onboard config (provider, model, endpoint, profile) |
| `~/.nemoclaw/credentials.json` | [`bin/lib/credentials.js`](bin/lib/credentials.js) | [`bin/lib/onboard.js`](bin/lib/onboard.js) | API keys (mode 600) |
| `~/.nemoclaw/sandboxes.json` | [`bin/lib/registry.js`](bin/lib/registry.js) | [`bin/nemoclaw.js`](bin/nemoclaw.js) | Sandbox registry (names, models, policies) |
| `~/.nemoclaw/state/nemoclaw.json` | [`nemoclaw/src/blueprint/state.ts`](nemoclaw/src/blueprint/state.ts) | [`nemoclaw/src/commands/slash.ts`](nemoclaw/src/commands/slash.ts) | Deployment state (lastRunId, timestamps) |
| `~/.nemoclaw/state/runs/<id>/plan.json` | [`nemoclaw/src/blueprint/runner.ts`](nemoclaw/src/blueprint/runner.ts) | [`nemoclaw/src/blueprint/runner.ts`](nemoclaw/src/blueprint/runner.ts) | Blueprint plan snapshots |

---

## Post-Onboard Commands

| Command | What it does | Key file |
|---------|-------------|----------|
| `nemoclaw list` | List all registered sandboxes | [`bin/nemoclaw.js`](bin/nemoclaw.js) → [`bin/lib/registry.js`](bin/lib/registry.js) |
| `nemoclaw <name> connect` | Shell into sandbox | [`bin/nemoclaw.js`](bin/nemoclaw.js) → `openshell sandbox connect` |
| `nemoclaw <name> status` | Sandbox health + inference info | [`bin/nemoclaw.js`](bin/nemoclaw.js) → `openshell sandbox get` |
| `nemoclaw <name> logs [--follow]` | Stream sandbox logs | [`bin/nemoclaw.js`](bin/nemoclaw.js) → `openshell logs` |
| `nemoclaw <name> policy-add` | Apply additional policy preset | [`bin/nemoclaw.js`](bin/nemoclaw.js) → [`bin/lib/policies.js`](bin/lib/policies.js) |
| `nemoclaw <name> policy-list` | List applied presets | [`bin/nemoclaw.js`](bin/nemoclaw.js) → [`bin/lib/policies.js`](bin/lib/policies.js) |
| `nemoclaw <name> destroy` | Teardown sandbox + NIM | [`bin/nemoclaw.js`](bin/nemoclaw.js) → [`bin/lib/registry.js`](bin/lib/registry.js) |
| `nemoclaw deploy <instance>` | Deploy to remote Brev GPU VM | [`bin/nemoclaw.js`](bin/nemoclaw.js) → [`scripts/brev-setup.sh`](scripts/brev-setup.sh) |
| `nemoclaw start` | Start Telegram bridge + tunnel | [`bin/nemoclaw.js`](bin/nemoclaw.js) → [`scripts/start-services.sh`](scripts/start-services.sh) |
| `nemoclaw stop` | Stop auxiliary services | [`bin/nemoclaw.js`](bin/nemoclaw.js) → [`scripts/start-services.sh`](scripts/start-services.sh) |
| `nemoclaw debug [--quick]` | Collect diagnostics | [`bin/nemoclaw.js`](bin/nemoclaw.js) → [`scripts/debug.sh`](scripts/debug.sh) |
| `nemoclaw uninstall` | Full teardown | [`bin/nemoclaw.js`](bin/nemoclaw.js) → [`uninstall.sh`](uninstall.sh) |

---

## Blueprint Profiles (`nemoclaw-blueprint/blueprint.yaml`)

| Profile | Provider | Endpoint | Model |
|---------|----------|----------|-------|
| `default` | NVIDIA | `integrate.api.nvidia.com/v1` | `nemotron-3-super-120b-a12b` |
| `ncp` | NVIDIA Cloud Partner | Dynamic | `nemotron-3-super-120b-a12b` |
| `nim-local` | OpenAI-compatible | `nim-service.local:8000/v1` | `nemotron-3-super-120b-a12b` |
| `vllm` | OpenAI-compatible | `localhost:8000/v1` | `nemotron-3-nano-30b-a3b` |

---

## Auxiliary Services

| Service | Script | Trigger | What it does |
|---------|--------|---------|-------------|
| Telegram Bridge | [`scripts/telegram-bridge.js`](scripts/telegram-bridge.js) | `TELEGRAM_BOT_TOKEN` env var | Forwards messages between Telegram bot and sandboxed agent |
| Cloudflared Tunnel | [`scripts/start-services.sh`](scripts/start-services.sh) | `nemoclaw start` | Creates public `*.trycloudflare.com` URL for remote access to port 18789 |
| Workspace Backup | [`scripts/backup-workspace.sh`](scripts/backup-workspace.sh) | Manual | Saves SOUL.md, USER.md, IDENTITY.md, AGENTS.md, MEMORY.md to `~/.nemoclaw/backups/` |
