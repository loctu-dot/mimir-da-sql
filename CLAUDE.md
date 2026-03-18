# Mimir DA SQL

A self-improving Data Analyst skill that writes SQL directly against MoMo's data domains via Mimir.

## Who Uses This

**C-level executives and department heads.** They ask broad business questions like:

> "Tinh hinh lam an nam 2025 so voi 2024 ntn?"
> "Moni dang phat trien hay di xuong?"
> "So sanh cac mang kinh doanh Q4/2025?"

These are vague on purpose — leaders think in business outcomes, not metrics. The DA must decompose these into multiple specific SQL queries, synthesize the results, and present a coherent business picture.

## How This Project Works

This is a **Claude Code skill**. When activated, you become a DA that explores MoMo business data. Unlike `mimir-da` which asks Vietnamese questions via Mimir's question API, **this DA writes SQL directly** using Mimir's domain metadata to understand table schemas.

**Critical:** To write correct SQL, you must first **understand what data exists**. Call Mimir's metadata/discovery APIs to map out available domains, tables, columns, and types. Store everything in `lt-memory/domains/`. The richer your domain knowledge, the better SQL you write.

## Progressive Disclosure

Load only what you need, when you need it.

| Level | What | When to Load |
|-------|------|--------------|
| **0** | This file | Always (you're reading it) |
| **1** | `docs/DA_PROMPT.md` | When doing DA work — your full skill instructions |
| **2** | `lt-memory/_index.md` → deep files | Before/after every query — your accumulated knowledge |
| **2+** | `docs/ref/` | Reference materials — domain guides, metric defs (loaded by DA_PROMPT.md as needed) |
| **2+** | `docs/scripts/` | Utility scripts — API helpers, formatters (executed, not read into context) |
| **3** | `docs/DIS_MIMIR_PROMPT.md` | Only for distillation (comparing BQ vs Mimir) — never for answering questions |

## The Learning Loop

```
RECALL → EXPLORE → LEARN → repeat
```

1. **RECALL** — read `lt-memory/_index.md`, load relevant domain/pattern files
2. **EXPLORE** — write SQL, execute it against the domain, get data back
3. **LEARN** — write what you discovered to `lt-memory/` (patterns, errors, domain knowledge)

The more you explore, the better you get.

## lt-memory Structure

```
lt-memory/
├── _index.md         ← Catalog of everything learned (read this FIRST)
├── domains/          ← Source A: raw Mimir schemas (auto-refreshed daily, NEVER edit)
├── knowledge/        ← Source B: learned gotchas + corrections (DA/user-written, never auto-overwritten)
├── patterns/         ← SQL queries that worked (reusable templates)
├── errors/           ← bigquery-access-map.md + mimir-insurtech-status.md
└── meta/             ← How Mimir itself behaves
```

**Rule:** `domains/` = machine-written (daily refresh safe). `knowledge/` = human-written (never overwritten). Never write learned knowledge into `domains/`.

## Quick Reference

| Key | Value |
|-----|-------|
| Prod | `https://s.mservice.io/mimir-server-to-server` |
| Dev | `https://s.dev.mservice.io/mimir-server-to-server` |
| User | `son.pham9@mservice.com.vn` |
| API field | `user_email` (NOT `user` — causes 500 error) |

**FS Domain IDs (verified 2026-03-03):**

| Domain | ID |
|--------|----|
| Paylater | `7e23d41a-0baf-4b36-84c3-07fb850bdb6e` |
| Vay Nhanh | `bb231763-b11c-45c6-9b0d-eb6d24588e3d` |
| TTT | `fa0fb3af-d3d9-4459-9a82-fb7c6eafab11` |
| InsurTech | `800bf3e8-a8ba-45c3-90d8-5f54bdaba156` |
| FI Solutions | `5cd09ae2-90b8-4102-a717-0ae6f649ff69` |
| Moni (QLCT) | `af241589-f5be-4b97-8928-fe0823c8dc75` |
| Chatbot Moni | `9066c2ad-5109-4fa9-abc0-06d85c6eed7e` |

## File Organization

**Keep the root clean.** Only `CLAUDE.md` and top-level directories belong in root.

| What | Where |
|------|-------|
| SQL query files | `docs/mimir/distill/sql-queries/` |
| Dashboard images | `docs/research/dashboards/` |
| Research outputs | `docs/research/YYYY-MM-DD-<slug>.md` |
| Experiment scripts | `experiments/` |

Never leave loose `.sql`, `.png`, or scratch files in root.

## Pitfalls

Read these before writing SQL:
- `lt-memory/knowledge/_general.md` — BQ access, Mimir behavior, reserved words
- `lt-memory/knowledge/<domain>.md` — per-domain gotchas (column names, filters, date semantics)
- `lt-memory/errors/bigquery-access-map.md` — which BQ datasets are accessible vs blocked
- Never fabricate column names. If unknown, mark `[UNKNOWN - verify]`.
- Save research to `docs/research/YYYY-MM-DD-<slug>.md`. For 3+ dimensions, create SPA dashboard.
- For validation reports: use MoMo SPA template (`shared-claude-config/skills/frontend-design/references/momo_spa_report_template.md`).

## BigQuery

### gcloud SDK setup

```bash
# Windows (MINGW64/Git Bash) — add to ~/.bashrc
export CLOUDSDK_PYTHON="$LOCALAPPDATA/Programs/Python/Python313/python.exe"
export PATH="$HOME/google-cloud-sdk/bin:$PATH"

# Mac — add to ~/.zshrc
export CLOUDSDK_PYTHON=/Library/Frameworks/Python.framework/Versions/3.11/bin/python3
export PATH="$HOME/google-cloud-sdk/bin:$PATH"
```

### Authentication (new device setup)

```bash
gcloud auth login
gcloud auth application-default login    # REQUIRED for Python SDK
gcloud config set project momovn-bu-fi-shared
```

### bq CLI usage

```bash
# Dry-run first (free, instant)
bq query --dry_run --project_id=momovn-bu-fi-shared --use_legacy_sql=false --format=csv < query.sql
# Execute
bq query --project_id=momovn-bu-fi-shared --use_legacy_sql=false --format=csv --max_rows=1000 < query.sql
```

### Python BigQuery SDK

```bash
# Install (use find_python.sh for portable path)
pip install google-cloud-bigquery google-cloud-bigquery-storage db-dtypes pandas
```

```python
import os, sys

# CRITICAL: Fix Windows cp1252 encoding — MUST be at top of every script
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    os.environ["PYTHONIOENCODING"] = "utf-8"

from google.cloud import bigquery

client = bigquery.Client(project="momovn-bu-fi-shared")
df = client.query("SELECT 1").to_dataframe()
```

### Windows-specific gotchas

| Issue | Fix |
|-------|-----|
| `UnicodeEncodeError: 'charmap' codec` | `sys.stdout.reconfigure(encoding="utf-8")` at top of script |
| `python3: No such file or directory` | Use `run_hook.sh` wrapper or `find_python.sh` |
| `quota exceeded` warning | Set `--project=momovn-bu-fi-shared` or `GOOGLE_CLOUD_PROJECT` env |
| `BigQuery Storage module not found` | `pip install google-cloud-bigquery-storage` |
| Vietnamese text crashes print() | cp1252 cannot encode Vietnamese — use UTF-8 reconfigure above |
| `VPC Service Control: Request is prohibited by organization's policy` | **STOP immediately. Do NOT retry.** See below. |

### VPC Service Control Error (CRITICAL — DO NOT RETRY)

If any BigQuery operation returns `VPC Service Control: Request is prohibited by organization's policy`:

**IMMEDIATELY stop all BigQuery-related tasks.** Do NOT retry, do NOT attempt workarounds.

Tell the user:
> BigQuery bi chan boi VPC Service Control. Ban can:
> 1. Bat **OpenVPN** (MoMo su dung OpenVPN) de ket noi vao mang noi bo cong ty
> 2. Hoac su dung mang WiFi tai van phong MoMo
>
> Day la chinh sach bao mat cua to chuc, khong the bypass duoc.
> Sau khi ket noi VPN/mang noi bo, thu lai lenh BigQuery.

This is a network-level restriction enforced by Google Cloud organization policy.
No amount of retrying, re-authenticating, or changing projects will fix it.
The ONLY solution is connecting via **OpenVPN** or MoMo office network.

### Windows Python Path

On Windows, `python3` does NOT exist in Git Bash PATH. Python hooks use `run_hook.sh` wrapper
that auto-detects Python across platforms (Mac/Linux/Windows).

- `run_hook.sh` searches: `python3` -> `python` -> `$LOCALAPPDATA/Programs/Python/*/python.exe`
- Python .py files keep standard shebang `#!/usr/bin/env python3` (for Mac/Linux compatibility)
- When running Python manually: `~/.claude/hooks/run_hook.sh script.py`

**Job project:** `momovn-bu-fi-shared`. Data lives in `momovn-prod`.
**PII columns** (`user_id`, `session_id`) have policy tags on some tables but are accessible via BU_FI dataset.

## Mimir Distill (Data Collection) — PAUSED

**Status:** Complete (25 batches, 200+ queries, 60+ lessons). On hold as of 2026-03-04.

**On resume:** Read `docs/mimir/distill/_index.md` FIRST, then `lt-memory/knowledge/_general.md`.

## Progress Tracking

| Timeframe | Where | How |
|-----------|-------|-----|
| **Past** | Git history | Commit meaningful work with descriptive messages |
| **Current** | `docs/current-progress.md` | Short 10-line note on what's in flight |
| **Future** | `docs/backlog.md` | Features, tasks, and ideas |

**Rule:** When you complete a substantial, working segment — commit it with a meaningful message. Git history is the primary progress tracker.

## Commands

| Command | What it does |
|---------|--------------|
| `/improve-da` | Reviews lt-memory/ learnings and upgrades DA_PROMPT.md |
| `/dis-mimir` | Stress-test Mimir accuracy: compare our SQL vs Mimir's answers across 6 metrics |
