# Deep Search Workflow — GROMACS_NA53 Research SOP

This is the workflow an agent follows for every literature/research task in this
repo. Imported 2026-09-04 from the AI_setup deep-search workflow
(`CliffVale` research environment) and adapted to this repo's layout
(`research/scripts/`, `research/deepsearch.log`).
It layers a rigorous research method on top of the installed skills and MCPs,
and it is **domain-aware**: the aptamer/biosensor pipeline below is appended when
the task is molecular/biosensor research.

> **House rules this SOP serves** (see `rules.md`): never fabricate URLs, versions,
> numbers, or cluster facts; prefer primary sources; mark uncertainty with ⚠️;
> only sources actually opened go into the ledger.

## 0. Scope & honesty rules
- Accuracy beats speed; citations beat confidence. Never fabricate URLs, versions, prices, dates, or numbers.
- Mark uncertain items with ⚠️. Prefer primary sources (papers, official docs, GitHub repos, standards bodies).
- If evidence is thin, say so — record partial failures (`source_count`/failed tools) in the log.

## 1. Frame the question
- Restate the task as 3–5 sub-questions. Each must be independently searchable.
- Identify what kind of answer is expected: overview, decision, method, tool comparison, benchmark.

## 2. Search (parallel, cheapest first)
1. Quick discovery search — snippets often answer simple questions outright.
2. Verification search with filters (site:, domain, time range) when a claim must be confirmed.
3. Full-page extraction only for the 1–2 URLs that matter (`read_url` / fetch MCP / firecrawl scrape).
4. Cross-check important facts across ≥2 independent sources.
- Use the MCP layer when available (firecrawl, agent-search, context7, semantic-scholar); fall back to built-in web_search.

### 2b. Scholarly literature (Semantic Scholar) — when the answer needs papers
Use for any scientific/domain question (methods, benchmarks, tool papers, state of the art):
1. `python3 research/scripts/s2_search.py "<query>" [--year 2020-2026] [--min-citations N] [--sort citationCount]`
   (keyless REST — works everywhere) **or** the `semantic-scholar` MCP tools
   (`paper_relevance_search`, `paper_title_search`, `paper_citations`, `paper_references`)
   when the client supports MCP and has `uv`.
2. Filter by field of study (Chemistry/Biology/…) and year; sort by relevance first,
   then re-rank by citationCount for the established work.
3. Verify before citing: open the DOI / open-access PDF (fetch MCP or firecrawl scrape)
   and actually read the claims you plan to attribute. Abstracts alone are not enough
   for strong claims — mark abstract-only findings ⚠️.
4. Walk the citation graph when chasing a method — faster than web search for lineage:
   - `research/scripts/s2_search.py --refs <DOI|paperId>` → foundations of a paper
   - `research/scripts/s2_search.py --cites <DOI|paperId>` → who extended it
   - `research/scripts/s2_search.py --author "Name"` → author profile
   - `research/scripts/s2_search.py --author-papers <authorId|"Name">` → an author's papers
   The MCP equivalents: `paper_references`, `paper_citations`, `author_search`, `author_papers`.
5. Only sources actually opened go into `research/REFERENCES.md` (record the S2 run id).

## 3. Synthesize
- Organize findings: **claims → evidence → confidence**.
- Flag contradictions and gaps explicitly.
- Write the report using the template at `research/REPORT-TEMPLATE.md`.

## 4. Log every run (mandatory)
Append one line to `research/deepsearch.log` via `research/scripts/log_run.py`:
```bash
python3 research/scripts/log_run.py --query "<question>" --report "<file>" --sources <n> --tools "<a,b,c>"
```
This is how we validate and improve the pipeline — if a run was weak, the log shows why.

## 5. Record references (mandatory)
Append only the sources **actually opened and used** to `research/REFERENCES.md`
(title, URL, why it was used). Never pre-populate it with sources you did not consult.

---

## Domain pipeline: Aptamer simulation for biosensor development

When the task involves aptamers, biosensors, SELEX, or molecular simulation, work through
this pipeline and record which layer each finding belongs to:

| Stage | Question to answer | Tools (open source unless noted) | Our layer |
|-------|--------------------|----------------------------------|-----------|
| 1. Sequence → secondary structure | What folds? | ViennaRNA/RNAfold, mfold/UNAFold, NUPACK, **GMfold** (high-throughput), FASTAptamer (SELEX HTS) | web + biopython |
| 2. Tertiary/3D structure | What 3D conformation? | SimRNA, RNAComposer, Rosetta, **AptaFold** (sequence→3D→docking), AlphaFold3/RoseTTAFold (protein/DNA/RNA), T_SELEX | web + biopython |
| 3. Docking aptamer–target | Where and how does it bind? | AutoDock Vina (polar pockets), AutoDock4 (hydrophobic), HADDOCK/HDOCK (protein–nucleic acid), **AptaFold** | web, optional local |
| 4. MD validation | Is the complex stable? | GROMACS, AMBER, NAMD | external (HPC) |
| 5. ML/sequence design | Design/rank better aptamers | **AptaBLE**, **AptaGPT**, AptaTRACE, DeepAptamer, AptamerRunner (clustering) | web + scikit-learn |
| 6. Biosensor-level modeling | Sensor response, optimization | **COMSOL Multiphysics** (SPR, electrochemical, nanophotonic), MATLAB link, MDPI SPR simulator | external (COMSOL) |
| 7. Experiments & stats | Design and analyze binding/SELEX data | experimental-design, statistical-power, statistical-analysis, uncertainty-and-units | skills |

**Literature grounding (do first):** every stage above should be anchored in papers —
search Semantic Scholar per stage (`research/scripts/s2_search.py`, layer: web) for the canonical
method/tool papers (e.g. AptaFold, AptaBLE, GMfold, FASTAptamer, COMSOL biosensor studies)
and verify tool claims against the paper + repo before recommending them.

Cross-check every tool's claims against its docs/repo before recommending it in a report.