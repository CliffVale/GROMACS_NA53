# Analysis: 67-Reference Aptamer/GROMACS Bibliography → Actionable for GROMACS_NA53

**Date:** 2026-09-04 · **Input:** `gromacs-aptamer-references.md` (67 refs, from the
protocol "Protocols for DNA Aptamer Folding: From Sequence to All-Atom GPU-Accelerated
GROMACS Simulations") · **Method:** per the research SOP — claims below come only from
sources **actually opened** this session (✅ read) or already in the repo ledger;
everything else is **screened** (title/venue metadata only, no content claims).

## 0. Reading status (legitimacy)

| Status | Sources |
|---|---|
| ✅ **Opened & read (this session)** | #11 AF3-aptamers (Ochoa & Milam 2025) · #18 cTnI ssDNA aptamers (Ropii et al. 2024) · #30 "How accurate are accurate force-fields for B-DNA?" (Dans et al. 2017) · #36 TBA G-quadruplex MSM folding (Bian et al. 2018) · #6 RNA-aptamer 3D-prediction MD assessment (Ropii et al. 2023) · #63 GROMACS mdrun-performance manual |
| 🔎 Screened (metadata/title only) | all others — no content claims made from them |
| ⛔ Blocked (not opened) | #1/#12/#13/#24/#26/#32/#50 (ACS), #4 (PubMed cookie-wall; abstract via title only), #25 (bioRxiv 403) — **do not cite as read** |

## 1. Technical extraction — core findings with numbers

### 1.1 Structure prediction for the Phase-5 input (highest leverage)
**#11 ✅** Ochoa & Milam, *ACS Synth Biol* 2025, 14(8):3049–3064, DOI 10.1021/acssynbio.5c00196:
- PDB landscape (Dec 2024): 19,788 nucleic-acid structures vs 224,025 proteins; of these
  **only 117 DNA + 232 RNA aptamer structures**, many redundant (e.g., 4DII/4DIH).
  → *scarce training data is the core limitation for any ML aptamer-structure tool.*
- AlphaFold 3 modeled PDB-resolved aptamers well **including G-quadruplexes and
  pseudoknots**; for non-PDB aptamers confidence dropped but GQ topology was still
  captured and known aptamer–protein binding interfaces were sometimes localized.
- Verdict: AF3 is a credible candidate to generate the **NA53 starting 3D model**, with
  MD refinement — exactly our pipeline's design (structure → equil → prod → analysis).

**#18 ✅** Ropii et al., *PLoS ONE* 2024, 19(5):e0302475 (six ssDNA aptamers vs cardiac troponin I):
- **Working ssDNA-aptamer modeling protocol**: 2D via **mFold** → 3D via **RNAComposer
  on a T→U RNA surrogate** → mutate U→T back (Discovery Studio) → **relax each model
  100 ns MD before docking** → dock → MD. Kd of the aptamers: picomolar.
- Takeaways: (a) the RNA-surrogate workaround exists because RNA 3D tools outnumber DNA
  ones — w3DNA/3dDNAi/AF3 are the direct-DNA alternatives; (b) "relax-before-use" is
  standard practice and matches our equil stage; (c) predicted complexes were
  electrostatics-driven (salt-bridge + H-bond + π-interactions) — useful when we later
  dock NA53↔NGAL.

**#6 ✅** Ropii et al., *PLoS ONE* 2023, 18(7):e0288684 (RNA aptamer 3D benchmark):
- mFold → RNAComposer → MD: models of 14–29 nt aptamers matched experimental geometry;
  **RNAComposer claims ~1.7 Å average RMSD**; noncanonical loop H-bonds **formed during
  MD** (MD actively improves the model) and **clustering is recommended to pick the
  representative structure**.
- MD settings used: GROMACS + **CHARMM36**, TIP3P, PME, **1.2 nm cutoff**, LINCS,
  V-rescale 300 K, Parrinello–Rahman 1 atm, 100 ns.
- Takeaway: our analysis stage already clusters; the "MD refines the predicted 3D"
  finding supports a modest pre-production relaxation (we do NVT/NPT; consider an
  unrestrained 5–10 ns "settling" prod if desired) and justifies post-hoc clustering
  of our own production.

### 1.2 Force-field choice (challenges our current amber99sb-ildn-DNA)
**#30 ✅** Dans et al., *Nucleic Acids Res* 2017, 45(7):4217–4230, DOI 10.1093/nar/gkw1355:
- FF history for DNA: parm94 (twist errors) → parm99 (α/γ artifacts) → **bsc0** (2011,
  gold standard ~decade) → **bsc1 (parmbsc1, 2016)** + Czech OL family (bsc0OL15 etc.).
- New-NMR validation of two dodecamers: **only last-generation AMBER FFs (BSC1 and
  BSC0OL15) show predictive power into the multi-microsecond regime** and reproduce
  sequence-dependent details; caveats: "experimental structures" themselves carry
  refinement artifacts (esp. NMR restraint averaging).
- **Implication for us:** our pipeline uses amber99sb-ildn, whose *DNA* parameters are
  pre-bsc0 (parm99-era) — the least reliable tier by this benchmark. bsc1/OL15 gmx ports
  exist (#31 UPOL gmxOL15, #34 intbio/gromacs_ff; bsc1 as amber99bsc1 in gromacs
  user-contributions, already in our ledger). **Recommendation (evidence-based): switch
  the DNA FF to parmbsc1 (or OL15) + re-run the local trial gate before production.**
  Change requires the rules.md "no FF change without evidence" gate — this benchmark is
  the evidence; decision log entry D-note required.

### 1.3 Folding feasibility (validates "no de novo folding in cMD")
**#36 ✅** Bian et al., *Biophys J* 2018, 114(7):1529–1538, DOI 10.1016/j.bpj.2018.02.021:
- Even the **15-nt thrombin-binding aptamer G-quadruplex cannot be folded by plain cMD**;
  only with advanced sampling (replica exchange) + Markov-state modeling did they map
  folding: intermediates (G-hairpin → G-triplex ×2 → double-hairpin), a misfolded
  syn/anti state, three fast pathways; TGT loop key.
- Reinforces the E2EDNA/lit-review conclusion already in our repo: **start production
  from a folded 3D input; enhanced sampling is a separate project** if folding kinetics
  ever become the question (menu: #44 REMD, #45/#47 enhanced-sampling reviews, #50 TBA
  free-energy landscape, #48–58 PLUMED metadynamics tutorials).

### 1.4 GROMACS performance levers (applies to our ct56 CPU + future GPU)
**#63 ✅** GROMACS manual, "Getting good performance from mdrun" (2026.3):
- Metrics: ns/day, hour/ns, ms/step, **Matom·steps/s**, Mnbf/s, MFlops (latter two need
  `GMX_DETAILED_PERF_STATS=1`). → we should log Matom·steps/s in benchmarks to compare
  across system sizes.
- CPU notes: single precision; self-built FFTW; gcc; **prefer AVX2 over AVX512 in
  GPU/parallel runs**; rhombic dodecahedron (we use it); `constraints=h-bonds` (we use);
  **4 fs timestep via `mass-repartition-factor`** (equilibrium-preserving; 2× throughput
  candidate for ct56 — needs validation run, not blind adoption).
- GPU-resident (`-update gpu`): keep `nstcalcenergy` infrequent (virial/energy overhead);
  `nstlist` 200–300 with PME + Verlet buffer often optimal (mdrun auto-tunes); few ranks
  per GPU (1–3); `gmx tune_pme` for PME-rank search.
- → Actionable now: (i) our prod.mdp `nstlist=10` is safe (Verlet auto-buffer) but
  setting 100–300 removes bookkeeping overhead on GPU-resident runs; (ii) confirm
  `nstcalcenergy` value in prod.mdp; (iii) log Matom·steps/s in the health KPI for
  cross-size comparisons.

## 2. Domain map of all 67 (tiered, screened unless marked ✅)

| Tier | Domain | #s (read ones ✅) |
|---|---|---|
| **A — aptamer structure prediction** | #4/5 protocol (DNA aptamer 3D + docking) ⛔, #11 ✅ AF3, #13 3dDNAi (ssDNA builder), #14 AF3 benchmarking, #21 AF3 DNA-nanomotif reliability, #22 truncation protocol (cf. Díaz-Fernández, already in our register), #16/#17 services/marketing |
| **A — aptamer MD case studies** | #1 (OTA aptamer–ligand thermodynamics) ⛔, #2 (SARS-CoV-2 RNA aptamers), #3 (17β-estradiol aptamer), #6 ✅, #7 (SELEX+MD, LPS), #8 (SARS-CoV-2), #18 ✅, #50 (TBA FEL) ⛔ |
| **B — nucleic-acid force fields** | #23/#30 ✅ bsc-family benchmarking, #24 (ss/dsDNA + DNA–protein FF), #25 (DNA/RNA hybrid FF; ⛔ blocked), #26 (OL21-vdW7), #27 (TBA direct folding, NAR), #28 (G-quadruplex FF), #29 (FF × ligand docking), #31 gmxOL15 port, #32 (free-energy FF refinement), #34 intbio/gromacs_ff, #35 (B↔A transition), #37 (high-alkali twist), #38 Amber-OL15-ECC (ions), #39 (self-consistent DNA params), #40 (OPC/TIP4PD destabilize RNA → supports our TIP3P), #44/#45 (enhanced sampling for FF benchmarking) |
| **C — enhanced sampling / folding** | #36 ✅ MSM, #44–#58 (REMD/REST2/metadynamics/PLUMED tutorials) |
| **D — GROMACS HPC & GPU** | #59 (ROCm AMD build), #60 (power capping arxiv), #61 (heterogeneous parallelization), #62 (AWS GPU), #63 ✅ mdrun performance, #64 (ENCCS PME GPU), #65 (MPS/MIG multi-sim), #67 (2018 mdrun perf) |
| **E — generic tutorials / low value** | #9/#10/#17/#19/#33/#41/#42/#43/#66 (biotech services, generic GROMACS tutorials, forum threads) — **not used** |

## 3. Actionable recommendations for GROMACS_NA53 (with confidence)

| # | Action | Evidence | Confidence |
|---|---|---|---|
| R1 | **Phase 5: try AlphaFold 3 for the NA53 3D model first**, alongside w3DNA/3dDNAi; relax the top model through our existing equil before production; keep seqfold/UNAFold 2D as input | #11 (aptamer GQ/pseudoknot OK; expect lower confidence for non-PDB 75-nt), #6 (MD refines predicted models) | high |
| R2 | **Reconsider DNA force field: parmbsc1 (or OL15) instead of amber99sb-ildn's parm99-era DNA**, using gmx ports #31/#34 or amber99bsc1 (user-contributions); validate with a local trial + rerun of `check_repo_integrity` before committing; record as decision-log entry | #30 (only bsc1/bsc0OL15 multi-µs predictive) | high (physics) / medium (effort: re-validate) |
| R3 | Keep TIP3P (no change) — OPC/TIP4PD can destabilize nucleic-acid structure | #40 (title-screened) | low (screened) |
| R4 | No de novo folding in cMD; if a folding-sampling study is ever desired, scope a separate replica-exchange/metadynamics project (menu in §1.3) | #36 + our E2EDNA lit-review | high |
| R5 | Add `Matom·steps/s` to the health/KPI benchmark line and log `GMX_DETAILED_PERF_STATS` runs for the final benchmark | #63 | medium |
| R6 | Tune prod.mdp for GPU-resident runs when GPUs arrive: `nstlist` 100–300, infrequent `nstcalcenergy`; on ct56 CPU evaluate 4 fs via `mass-repartition-factor` behind a validation gate | #63 | medium (needs bench) |
| R7 | If we later dock NA53↔NGAL: use relaxed-aptamer + electrostatics-aware docking (our analysis clustering feeds representative structures) | #18 (protocol), #12 (already registered) | high |

## 4. Corrections / notes vs our register
- #22 = Díaz-Fernández 2025 (ChemRxiv 10.26434/chemrxiv-2025-k5mzk) — already in `docs/REFERENCES.md`; the RG link here is the same work.
- #12 = Rodríguez Serrano 2022 — already in ledger (ACS 403 here; we hold the earlier PMC/ACS metadata).
- #30 and #23 are the same article (NAR vs PMC mirror) — deduplicated above.

*Report follows research/REPORT-TEMPLATE.md; sources ledger + run log updated alongside.*
