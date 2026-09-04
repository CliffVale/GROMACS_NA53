# 🔬 Research SOP — Deep-Search Workflow (imported 2026-09-04)

This directory is the **research arm of GROMACS_NA53**: a rigorous, anti-hallucination
literature-workflow that produced the founding NA53/NGAL review below and will be used
for every future literature task (force-field deep-dives, docking method choices,
biosensor modeling, publication writing, …).

Imported from the `CliffVale` AI_setup deep-search environment and adapted to this
repo's layout. The methodology is agent-agnostic — follow it whether a human or an AI
does the search.

## What lives here

| File | Purpose |
|------|---------|
| `WORKFLOW.md` | The spec: frame → search (cheapest first) → verify → synthesize → **log + record** |
| `REPORT-TEMPLATE.md` | Evidence-report scaffold (claims → evidence → confidence, gaps, sources) |
| `REFERENCES.md` | Ledger of **only actually-opened** sources (never pre-populated) |
| `deepsearch.log` | Append-only JSONL run log (one line per run, via `research/scripts/log_run.py`) |
| `reports/` | Completed research reports |
| `scripts/s2_search.py` | Keyless Semantic Scholar search + citation-graph helper (stdlib only) |
| `scripts/log_run.py` | Appends one JSONL entry to `deepsearch.log` |

## Mandatory run procedure (every research task)

1. Read `WORKFLOW.md` and follow it (frame 3–5 sub-questions → search → verify →
   synthesize). For scholarly questions use `research/scripts/s2_search.py`
   (keyless; ~100 shared req/5 min — the `--dois` route is more reliable when the
   search pool is busy; a free `SEMANTIC_SCHOLAR_API_KEY` removes the limit).
2. Write the report from `REPORT-TEMPLATE.md` into `research/reports/` with a
   `YYYY-MM-DD-<topic>.md` name.
3. Append only sources **actually opened** to `REFERENCES.md`.
4. Log the run:
   ```bash
   python3 research/scripts/log_run.py --query "<question>" \
     --report "research/reports/<file>.md" --sources <n> \
     --tools "web_search,read_url,s2_search.py" [--note "..."]
   ```
5. Update `memory.md` §2 with the new artifact.

## Golden rules (same as `rules.md`)

- Never fabricate URLs, versions, numbers, DOIs, or cluster facts.
- ⚠️ marks a genuine unknown — never fill it later "by inference".
- Primary sources beat aggregators; abstracts alone are not enough for strong claims.
- If evidence is thin, say so — the log records partial failures too.

## Current reports

- `reports/2026-09-03-ngal-na53-gromacs-litreview.md` — **founding review**: NA53
  identity/sequence/Kd (Hong 2019, primary source), E2EDNA hierarchical folding
  methodology, DNA force fields in GROMACS, protocol outline. Carries a
  reconciliation banner: §4–§5 are Taiwania-2 reference — this repo's `slurm/` +
  `configs/` are the verified Taiwania-3 implementation.
- `reports/2026-09-03-aptamer-biosensor-deepsearch.md` — aptamer-in-silico toolchain
  survey (2D/3D/docking/MD/ML/COMSOL) with confidence-graded evidence table.
