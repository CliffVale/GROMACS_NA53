# NA53 (NGAL aptamer) DNA Folding Simulation in GROMACS — Literature Review & Validated Protocol Outline

**Run date:** 2026-09-03 · **Pipeline:** deep-search workflow (this repo)
**Prepared for:** NCHC iService HPC (GPU, Slurm) deployment of a GROMACS simulation of the NA53 ssDNA aptamer targeting NGAL
**Method:** every factual claim below was checked against a primary source opened during this run (full text, official docs, or API records). Sources are numbered [S#] and only sources actually consulted are listed. Items that could **not** be verified are flagged ⚠️ — they are *not* filled in by inference.

> ⚠️ **RE-IMPORTED 2026-09-04 into GROMACS_NA53 as the founding literature review**
> (Research SOP — see `research/README.md`). Two reconciliations apply, per
> `docs/TRANSCRIPTS_DEEP_ANALYSIS.md` findings F1/F2:
>
> 1. **Cluster:** §4–§5 below describe the *Taiwania-2* GROMACS guide (GPU, `gp1d`,
>    module 2023.4, NGC containers). Your verified cluster is **Taiwania-3,
>    CPU-only** — the authoritative deployment is `slurm/` + `environment.yml` in
>    this repo (conda-forge GROMACS 2024.4 CPU, `--partition=ct56`, account
>    `mst115368`, `-nb auto`).
> 2. **Cutoff:** the Stage-3 mdp sketch says `rcoulomb = 1.0–1.2`; the locked,
>    trial-validated value in `configs/*.mdp` is **0.8 nm**. Configs win.
>
> Treat this file as **literature grounding**; the repo's scripts/configs/slurm
> are the **implementation**.

---

## 0. Executive summary (claims → evidence → confidence)

| # | Claim | Evidence | Confidence |
|---|-------|----------|-----------|
| C1 | NA53 is a 75-nt ssDNA aptamer against human NGAL, selected by magnetic-bead SELEX (8 rounds), reported with Kd = 32.52 nM | Hong et al. 2019 full text [S1] | High (primary source, read in full) |
| C2 | NA53 full sequence (5′→3′): `AGCAGCACAGAGGTCAGATG-GCGCTGGATAGCAAGATCACGTTATCATCGTAAAC-CCTATGCGTGCTACCGTGAA` (75 nt = 20 fixed + 35 random + 20 fixed) | [S1] raw article XML (sequence printed in main text; spaces inside the random region are typographic — removing them gives exactly 35 nt and total 75 nt matching the library design) | High, with note: retranscribe from [S1] §Results before simulation; sequence was never independently deposited in a database |
| C3 | The authors predicted NA53 secondary structure with UNAFold/mfold at **25 °C, 0.1 M Na⁺, 0.001 M Mg²⁺** and report agreement with their binding data | [S1] | High — these are the ionic conditions our MD should mirror |
| C4 | De novo atomistic folding of a ~75-nt ssDNA by brute-force MD is not tractable; published practice is a hierarchical pipeline: (i) 2D structure prediction at experimental conditions → (ii) fast 3D fold guided by that 2D structure → (iii) explicit-solvent all-atom MD to refine and *validate stability* (ns–µs) | E2EDNA protocol [S2]: “brute force approaches such as naïve molecular dynamics search are prohibitively computationally expensive”; oxDNA coarse-graining [S10] for folding-scale sampling | High |
| C5 | GROMACS ships **no** native parmbsc1/OL15 DNA force field; verified options for DNA in GROMACS are community ports: `amber99bsc1.ff` (parmbsc1, verified against AMBER by V. Lindahl), `amber14sb_parmbsc1.ff` (ff14SB + parmbsc1), `amber14sb_OL15.ff` (OL15 + χOL3, with corrected Na⁺ JC parameters in the “corrected” release), or CHARMM36 (MacKerell lab GROMACS files; CHARMM27 is the officially supported built-in) | GROMACS user-contributions page [S3]; GROMACS 2024.3 manual “Force fields in GROMACS” [S4] | High |
| C6 | Recommended default for DNA B-form stability is **parmbsc1**; CHARMM36 is a credible alternative with its own mdp settings (force-switch, rvdw 1.2 nm etc.) | [S3] (parmbsc1 = Ivani et al., *Nat. Methods* 13(1):55–58, cited on the contribution page), [S4] (CHARMM36 mdp settings), [S9] skill guidance | Medium-High (default recommendation is a judgment call on top of verified facts — flagged as such) |
| C7 | NCHC Taiwania-2 provides GROMACS 2023.4 (native GPU module) and 2023.2/2022.1 (Singularity containers from NGC), Slurm scheduler, GPU partitions, `sbatch` workflows | Official NCHC GROMACS quick-usage guide [S5] | High (official NCHC doc, read in full) — but user's specific cluster/node (iService account) must be confirmed on login (see §5 checklist) |
| C8 | No published all-atom MD *folding* study of NA53 was found; downstream literature citing Hong 2019 is biosensor-oriented | Semantic Scholar citation graph of [S1] retrieved 2026-09-03 [S8] | Medium — absence-of-evidence statement, limited to indexed citing papers at retrieval date ⚠️ |

---

## 1. The molecule: NGAL and the NA53 aptamer (verified)

### 1.1 Target: NGAL (lipocalin-2, LCN2)
- NGAL = neutrophil gelatinase-associated lipocalin, a ~25 kDa secreted lipocalin; established early biomarker for acute kidney injury (AKI) [S1 and references therein].
- Structure: human NGAL crystal structures exist in the PDB — **1NGL** (human NGAL), and siderophore/catechol complexes **1L6M**, **1X71**, **3FW4** (entries verified to exist via RCSB; not needed for the *folding* stage, only for a future aptamer–protein docking/binding stage) [S11 ⚠️ metadata-only].

### 1.2 The NA53 aptamer (primary source)
- **Citation:** Hong X, Yan H, Xie F, et al. *Development of a novel ssDNA aptamer targeting neutrophil gelatinase-associated lipocalin and its application in clinical trials.* J Transl Med. 2019;17:204. DOI 10.1186/s12967-019-1955-7. PMID 31215436; PMC6582607. [S1] (Crossref + PubMed records verified: [S6][S7])
- **Selection:** magnetic-bead SELEX against NGAL, 8 rounds; candidates NA10/NA21 rejected (weak binding), **NA36, NA42, NA53** retained; Kd (qPCR) = 43.59 / 66.55 / **32.52 nM** — NA53 strongest [S1].
- **Library design:** total 75 nt = 20-nt fixed 5′ arm + 35-nt random core + 20-nt fixed 3′ arm [S1].
- **Sequence (as printed in the paper's main text):**
  - NA53 = `AGCAGCACAGAGGTCAGATG` + `GCGCTGGATAGCAA GATCACGTTATCATCGTAAAC` + `CCTATGCGTGCTACCGTGAA`
  - The embedded spaces appear in the published text inside the random region (also for NA36) and are **typographic artifacts**: NA53 core = `GCGCTGGATAGCAAGATCACGTTATCATCGTAAAC` (35 nt) ⇒ full 75 nt. NA42's core is printed without spaces, confirming the pattern.
  - ⚠️ **Do not trust any third-party copy of this sequence.** Transcribe it from [S1] (PMC6582607, §Results / Fig. 2 legend area) and verify length = 75 before simulation. There is no sequence database (e.g., RCSB/ENA) entry for NA53.
- **Secondary structure:** authors used UNAFold/mfold (DNA folding form) at **25 °C, 0.1 M Na⁺, 0.001 M Mg²⁺** and state predictions are consistent with their results [S1]. This is our anchor for 2D structure comparison.
- **Specificity context (assay-level):** ELAA using NA53 showed no cross-reaction with human albumin/globulin; sensitivity 100 %, specificity 90 % in their cohort [S1]. (Assay facts — useful background, not directly simulation inputs.)

### 1.3 What "folding simulation" can legitimately mean here
For a 75-nt ssDNA aptamer there is **no published 3D structure** (⚠️ not found; if one exists it must be supplied). Therefore the simulation target is the *solution conformational ensemble* of NA53 at the paper's conditions. Three distinct scientific questions must not be conflated:

1. **Which 2D fold(s)?** → best answered by UNAFold/NUPACK-type free-energy prediction (cheap, fast), NOT by MD [S2].
2. **Is the predicted 2D fold stable / which 3D conformations populate?** → answered by coarse-grained sampling (oxDNA) plus explicit-solvent all-atom MD starting from folded models, measuring stem persistence, base-pair occupancy, RMSD/Rg distributions [S2][S10].
3. **De novo folding from a fully extended chain** → **not feasible** with atomistic MD at current sampling (µs–ms folding times vs. ns/day sampling); do not design the protocol around it [S2].

---

## 2. Methodology literature (verified)

### 2.1 End-to-end aptamer simulation protocols
- **E2EDNA** [S2] (Kilgour M, Liu T, Walker BD, Ren P, Simine L. *E2EDNA: Simulation Protocol for DNA Aptamers with Ligands.* J Chem Inf Model. 2021;61(9):4139–4144. DOI 10.1021/acs.jcim.1c00696; PMC9536994) — the closest published blueprint for exactly this task:
  - Pipeline: FASTA sequence → 2D prediction (NUPACK/seqfold) at experimental temperature/ionic strength → directed 3D folding with **MacroMoleculeBuilder (MMB)** using fictitious base-pair forces → all-atom explicit-water MD (they used AMOEBA/Tinker9; **engine-agnostic by design**) to refine and *evaluate* the fold → free-energy profiles along reaction coordinates F(r) = −kT·ln P(r).
  - Their case study: 5 parallel runs × 20 ns (2 fs), discarding the first 2 ns; ~5–10 ns/day on NVIDIA V100 — a concrete GPU-throughput benchmark for an ssDNA + water system.
  - Key methodological statements worth quoting in any protocol write-up: secondary-structure tools cannot always give high-confidence folds; MD evaluates rather than discovers the fold; brute-force folding is prohibitively expensive [S2].
- **oxDNA** [S10] (Sengar A, et al. *A Primer on the oxDNA Model of DNA: When to Use It, How to Simulate It, and How to Interpret the Results.* Front Mol Biosci. 2021;8:693710. DOI 10.3389/fmolb.2021.693710) — nucleotide-level coarse-grained model; the standard tool for *folding/assembly-scale* questions (hairpin formation, melting, conformational search over µs–ms in CG time). Recommend using it to generate/rank starting ensembles before atomistic MD, or as an independent cross-check of 2D predictions. (⚠️ Retrieved as title/abstract + oxdna.org snippet; full text not read in this run — flag before deep reliance.)
- The K-Dense **molecular-dynamics** skill (used as the working methodology base per request) codifies the same conventional workflow — minimization → NVT → NPT → production; PME; 2 fs with H-bond constraints; nucleic acids → bsc1-class FF + TIP3P — implemented for OpenMM/MDAnalysis [S9]. We adopt its *workflow discipline* and analysis vocabulary (RMSD/RMSF/contact maps) and execute on **GROMACS** on NCHC (GROMACS is explicitly listed as an alternative engine in that skill).

### 2.2 Force fields for DNA in GROMACS (verified availability)
From GROMACS user contributions [S3] (all files explicitly for DNA in GROMACS):
- `amber99bsc1.ff.tgz` — **parmbsc1** for DNA (Ivani et al., *Nat. Methods* 13(1):55–58, 2016, as cited on the page); verified against AMBER by V. Lindahl; requested citation PLOS Comput Biol DOI 10.1371/journal.pcbi.1005463.
- `amber14sb_parmbsc1.ff.tar.gz` — ff14SB protein + parmbsc1 DNA (5 Dec 2017).
- `amber14sb_OL15.ff_corrected-Na-cation-params.tar.gz` — AMBER **OL15** DNA + χOL3 RNA + ff14SB, with **corrected Na⁺ Joung–Cheatham ε** (an earlier release on that page had a Na⁺ ε error — always use the *corrected* archive) [S3].
- `amber12sb.ff` / `amber14sb.ff` — older ff99bsc0 DNA / χOL3 RNA ports.
- CHARMM27 is the built-in officially supported nucleic-acid-capable port; **CHARMM36 GROMACS files are distributed from the MacKerell lab** and need the dedicated mdp block (force-switch VdW, rlist/rvdw 1.2 nm, rvdw-switch 1.0 nm, PME rcoulomb 1.2 nm, DispCorr no) [S4].
- Native AMBER support in GROMACS covers AMBER94/96/99/99SB/99SB-ILDN/03/GS only — **none includes modern DNA (bsc1/OL15) parameters**, so a community port (above) or CHARMM36 must be installed for DNA work [S4].

**Recommendation (decision, flagged as such):** default **parmbsc1** (`amber99bsc1.ff`, or `amber14sb_parmbsc1` if later adding protein) with TIP3P; treat **CHARMM36** as the cross-validation force field (second replica set). Rationale: parmbsc1 is the most widely benchmarked DNA FF for duplex stability; a second-FF comparison is the strongest published-practice defense against force-field artifacts in ssDNA loops ⚠️ (ssDNA loop sampling remains a recognized weak spot for all fixed-charge FFs — see §4 limitations).

### 2.3 Ions and solution conditions
- Paper conditions for 2D prediction: 25 °C, 0.1 M Na⁺, 1 mM Mg²⁺ [S1]. For the MD solution:
  - Start with **0.1 M NaCl** neutralization (monovalent) — the best-validated regime for these FFs; use corrected Na⁺ parameters if the OL15 port is used [S3].
  - **Mg²⁺ is the hard part.** Non-polarizable Mg²⁺ models are approximate; ⚠️ do not silently include 1 mM MgCl₂ and expect quantitative ion effects. Recommended design: run the main production set at 0.1 M NaCl; add a *sensitivity* arm at 0.1 M NaCl + 1 mM MgCl₂ with published Mg²⁺ parameters (e.g., Åqvist or Joung–Cheatham) and compare base-pair occupancies/Rg. State this explicitly in the protocol; do not claim quantitative Mg²⁺ fidelity.
- Water: TIP3P for AMBER ports; CHARMM-TIP3P with CHARMM36 [S4][S9].

### 2.4 Conventional equilibration protocol (translated to GROMACS)
Adopted from [S2] practice, [S9] skill workflow, and [S4]/[S5] platform constraints:
1. Energy minimization (steepest descent → conjugate gradient; tolerance ~10 kJ/mol/nm, or 1000 kJ/mol/nm² style criterion per standard GROMACS tutorials ⚠️ pick one criterion and state it).
2. NVT equilibration (100 ps, 2 fs, LINCS on H-bonds, v-rescale thermostat, position restraints on solute heavy atoms).
3. NPT equilibration (100–500 ps, Parrinello–Rahman or Berendsen during eq; target 1 bar).
4. Production: multiple independent replicas (E2EDNA: 5×; recommend ≥3), ≥100 ns each planned, 2 fs, PME, Verlet cutoff scheme; checkpointed.
5. Discard equilibration fraction before analysis (E2EDNA discards first 2 ns of their 20 ns) [S2].

---

## 3. Where the NA53-specific unknowns sit (honesty map)

| Unknown | Status | Consequence for protocol |
|---|---|---|
| NA53 3D structure | Not published ⚠️ | Must build starting models from 2D prediction + folding tools (§4 stage 2) |
| NA53 2D structure at 25 °C/0.1 M Na⁺/1 mM Mg²⁺ | Authors ran UNAFold/mfold [S1] but did **not publish the resulting dot-bracket/diagram in the accessible text** ⚠️ | Re-run UNAFold (DNA folding form, same conditions) as Stage 1; compare with their "consistent" claim |
| Terminal chemistry of the synthesized aptamer (5′ biotin/phosphorylation etc.) | Not stated in main text ⚠️ | Ask experimental collaborator; default to unmodified 5′-OH/3′-OH ssDNA in model and document |
| Whether NA53 folds into canonical duplex stems vs. non-canonical motifs (G-quadruplex etc.) | Unknown | Check sequence motifs computationally in Stage 1; non-canonical motifs need special FF handling (parmbsc1 covers standard DNA well; G-quadruplex needs validated parameters — flag ⚠️) |
| Existing MD of NA53 | None found (citation graph of [S1], retrieved 2026-09-03: biosensor papers only) [S8] ⚠️ | This run would be a first — no direct precedent to copy; rely on general aptamer MD literature |

---

## 4. Validated protocol outline (GROMACS on NCHC GPU)

> This is the literature-validated skeleton. Concrete `.mdp`, `.tpr` filenames, partition/account names and node hardware must be finalized **on the NCHC login node** (checklist §5). Every parameter below is either from [S2]–[S5] or explicitly flagged as a to-be-decided value.

### Stage 0 — Input QA (1 day, desk)
- Transcribe NA53 sequence from [S1]; verify 75 nt, only A/C/G/T; record orientation 5′→3′. (⚠️ no database copy exists — see §1.2.)
- Record target conditions: 298.15 K (25 °C), 0.1 M Na⁺, 1 mM Mg²⁺ optional arm [S1].
- Decide terminal chemistry (⚠️ ask collaborator) and whether 5′/3′ fixed arms must be *included* — they are part of the published sequence and likely contribute to folding; do not trim without experimental justification.

### Stage 1 — Secondary structure prediction (hours)
- UNAFold/mfold DNA folding form at exactly 25 °C, 0.1 M Na⁺, 1 mM Mg²⁺ (reproduce [S1] conditions) and cross-check with NUPACK locally (E2EDNA precedent [S2]).
- Record: minimum-free-energy dot-bracket, suboptimal ensemble (≥5 structures within ~1–2 kcal/mol), per-base pair probabilities. Flag non-canonical motifs (G-tracts, etc.) for Stage 2 decisions.

### Stage 2 — Starting 3D models (1–3 days)
Option A (primary, follows E2EDNA): build directed 3D folds from the Stage-1 pairings with **MacroMoleculeBuilder** (MMB) [S2]; relax each in MD.
Option B (coarse-grained pre-screen): **oxDNA** simulations to generate/screen conformational ensembles and folding behavior [S10]; export candidate states (backmapping oxDNA→atomistic is tooling-dependent ⚠️ verify tacoxDNA/oxView support before committing).
Option C (if 2D is a simple hairpin): build directly with standard nucleic-acid builders, then equilibrate.
Deliverable: ≥3 chemically distinct starting models (different suboptimal 2D folds where plausible) so atomistic results do not depend on one guess.

### Stage 3 — Atomistic setup in GROMACS
- Force field: parmbsc1 via `amber99bsc1.ff` (or `amber14sb_parmbsc1`) [S3]; install under `$HOME/gromacs/ff/` or a project dir; **pin the FF version and record its checksum/DOI in the run log** (reproducibility).
- Topology: `gmx pdb2gmx` with DNA residue naming per the chosen FF; verify no missing atoms/termini warnings.
- Box/solvation: dodecahedron, solute–box distance ≥ 1.0 nm; TIP3P [S4][S9].
- Ions: neutralize with Na⁺, then add NaCl to 0.1 M; optional arm: +1 mM MgCl₂ with published Mg²⁺ params ⚠️ (§2.3).
- mdp essentials: `integrator=md`, `dt=0.002`, `constraints=h-bonds`, `cutoff-scheme=Verlet`, `coulombtype=PME`, `rcoulomb=1.0–1.2` (state the choice; CHARMM36 requires 1.2 + force-switch block [S4]), thermostat v-rescale 298.15 K, barostat Parrinello–Rahman 1 bar (production).

### Stage 4 — Minimization & equilibration (hours, GPU)
EM (steepest → CG) → NVT 100 ps with position restraints → NPT 100–500 ps → production prep. Check: no LINCS warnings, stable T (298.15 ± few K), density ~1000 kg/m³.

### Stage 5 — Production (NCHC GPU; the long pole)
- ≥3 independent replicas (different random seeds / initial velocities), ≥100 ns each as planned; extend in 100 ns chunks with `mdrun -cpi` checkpoint restarts (E2EDNA used 5×20 ns as their minimum-quality example; we scale to ≥3×100 ns given a ~75-nt system) [S2].
- Throughput planning: E2EDNA reported ~5–10 ns/day on a V100 for a small aptamer+water complex with AMOEBA (expensive FF); with parmbsc1/TIP3P on modern NCHC GPUs expect substantially higher (10–100×), but **measure** with a 5,000-step benchmark on the target node before scheduling (NCHC guide runs exactly such benchmarks [S5]). Budget wall-time per 100 ns from the measured rate.

### Stage 6 — Analysis & validation (against literature anchors)
- Structural metrics: RMSD (per-region: fixed arms, core), RMSF per nucleotide, radius of gyration, base-pair occupancy/H-bond map vs. the Stage-1 2D prediction (the decisive comparison — [S1] predicted structure at the same ionic conditions), secondary-structure persistence over time.
- Tools: GROMACS built-ins (`gmx rms/rmsf/gyrate/hbond/energy`) + MDAnalysis [S9] post-processing; ⚠️ DSSR/x3DNA helical analysis requires separate install (verify on cluster or run locally).
- Ensemble validation: replica reproducibility (distributions, not single snapshots); block-error/autocorrelation for reported means; report free-energy-like profiles F(r) = −kT ln P(r) along chosen coordinates only when sampling is demonstrably converged (E2EDNA practice [S2]).
- Acceptance criteria (pre-registered in the run log): EM converges; equilibration stable; ≥2 replicas agree within uncertainty on (i) which stems persist >50 % of trajectory, (ii) Rg distribution overlap; persistent pairing is consistent with the UNAFold minimum-free-energy structure at the same conditions; if the aptamer stays extended/heterogeneous across replicas, report that honestly (it is a valid finding for ssDNA) rather than forcing a fold.

### Stage 7 — Reporting (this repo)
Write report from `research/REPORT-TEMPLATE.md` into `research/reports/`; append only sources actually read to `research/REFERENCES.md`; log each run with `research/scripts/log_run.py` (include FF version, GROMACS version, GPU node, seed, ns/day measured, replica id).

---

## 5. NCHC iService execution notes (verified + on-node checklist)

Verified from the **official NCHC GROMACS quick-usage guide** [S5] (Taiwania-2, NCHC software team):
- Scheduler: **Slurm** (`sbatch`, `squeue`); job accounting via `#SBATCH --account=<JobAccount>`.
- GROMACS available two ways on Taiwania-2:
  1. **Native GPU module, GROMACS 2023.4** at `/opt/ohpc/pkg/gromacs/2023.4` — source usage script `source /opt/ohpc/pkg/gromacs/2023.4/gromacs/GromacsUsage.sh`, then `srun --mpi=openmpi gmx_mpi mdrun … -nb gpu`. Examples shipped under `/opt/ohpc/pkg/gromacs/2023.4/example`.
  2. **Singularity container (GROMACS 2022.1/2023.2)** — e.g., `module load singularity`; build `docker://nvcr.io/hpc/gromacs:<TAG>` or use prebuilt `/opt/ohpc/pkg/gromacs/container/gromacs-2022.1.sif`; run with `singularity run --nv -B ${PWD}:/host_pwd --pwd /host_pwd ${SIF} gmx mdrun -ntmpi <NGPU> -nb gpu -ntomp $OMP_NUM_THREADS …`.
- GPU request pattern: `--partition=gp1d --gres=gpu:N --ntasks-per-node=N --cpus-per-task=4`; `-ntmpi` = number of GPUs; `OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}`; `-pin on`.
- Benchmark practice encouraged by NCHC before real runs (water_GMX50_bare testcase, 5,000 steps) [S5].
- Older native wrapper `source setgromacs_2018` is flagged **"will not be updated"** — do not build the protocol on it [S5].

**On-node verification checklist (do this first via SSH — do not assume):**
1. `module avail 2>&1 | grep -i -E 'gromacs|singularity'` → which versions exist on *your* cluster (guide is Taiwania-2-specific; your iService project may land elsewhere ⚠️).
2. `sinfo -p gp1d` (or `sinfo`) → real partition names/GPU types; `nvidia-smi` on a test node → GPU model (affects throughput estimate).
3. Confirm your Slurm `--account` value (`sacctmgr show assoc user=$USER` or portal).
4. Check GROMACS CPU/GPU build: `gmx_mpi --version`; verify CUDA-enabled build (`acceleration: CUDA` in version output).
5. Container path exists: `ls /opt/ohpc/pkg/gromacs/container/`.
6. Home/scratch quotas — DNA+water systems are ~0.5–2 GB per run incl. trajectories; plan storage.
7. GROMACS license: LGPL — free to use; no license file needed [S5 states community project; FF ports are free but each has its citation obligation (parmbsc1/OL15 papers) — cite in outputs].

---

## 6. Hallucination-avoidance rules applied in this review (and to carry into the run)
1. NA53 sequence came from the publisher XML of the primary paper, cross-checked for length (75 nt) and library architecture (20/35/20) — not from memory or third-party sites.
2. DOI corrected during verification: the supplementary-material URL truncates the DOI; Crossref + PubMed both give **10.1186/s12967-019-1955-7** (an initial guess of `…1955-0` was wrong and is discarded here) [S6][S7].
3. Force-field *availability in GROMACS* statements are quoted from GROMACS pages [S3][S4]; citations of Ivani 2016 / OL15 are secondhand (as cited on those pages) — flagged, and the originals should be read before the protocol is published.
4. Everything marked ⚠️ is a genuine unknown, not a placeholder to be filled later by the LLM: e.g., actual GPU node of your iService account, NA53 terminal chemistry, existence of a published NA53 3D structure.
5. No downstream claim is invented: the S2 citation graph returned the biosensor papers listed; none was read in full, so they are only cited as “citing works identified at retrieval date” [S8].

---

## 7. Recommended immediate next steps (for you)
1. **On NCHC:** run the §5 checklist; report back partition/account/GPU model + `gmx_mpi --version` and which GROMACS delivery (module vs container) exists → I finalize the Slurm scripts + `.mdp` set.
2. **Sequence:** confirm NA53 terminal chemistry (5′ modification?) with your lab/experimental partner; send me confirmation and I lock the FASTA into the repo (`data/`).
3. **Stage 1:** I can run the UNAFold-equivalent prediction locally (NUPACK via Python, same conditions 25 °C / 0.1 M Na⁺ / 1 mM Mg²⁺) and generate the 2D candidates to seed Stage 2 — say go.
4. Then: Stage-2 model building → Stage-3 setup → benchmark on the GPU node → production.

---

## Sources actually used in this run
[S1] Hong X et al. 2019. J Transl Med 17:204 — full text (Europe PMC XML PMC6582607) — https://europepmc.org/article/PMC/PMC6582607 (read in full; sequence + conditions extracted)
[S2] Kilgour M et al. 2021. E2EDNA. J Chem Inf Model 61(9):4139–4144 — https://pmc.ncbi.nlm.nih.gov/articles/PMC9536994/ (read in full)
[S3] GROMACS user contributions (force fields incl. amber99bsc1/parmbsc1, OL15 corrected) — https://www.gromacs.org/user_contributions.html (read)
[S4] GROMACS 2024.3 manual, “Force fields in GROMACS” — https://manual.gromacs.org/2024.3/user-guide/force-fields.html (read)
[S5] NCHC software team, “GROMACS quick usage guide” (Taiwania-2) — https://hackmd.io/@nchc-software/B1iK3ZTUF (read)
[S6] PubMed esummary record PMID 31215436 (citation + DOI) — NCBI eutils (read via API)
[S7] Crossref API record DOI 10.1186/s12967-019-1955-7 (journal/volume/article metadata) — https://api.crossref.org/works/10.1186/s12967-019-1955-7 (read via API)
[S8] Semantic Scholar citation graph of DOI 10.1186/s12967-019-1955-7 (citing papers list, 8 shown) — S2 Graph API, retrieved 2026-09-03 (metadata only)
[S9] K-Dense-AI/scientific-agent-skills: repo README + `molecular-dynamics/SKILL.md` — https://github.com/K-Dense-AI/scientific-agent-skills (read)
[S10] Sengar A et al. 2021. “A Primer on the oxDNA Model of DNA.” Front Mol Biosci 8:693710 — title/abstract via search snippet ⚠️ not read in full — https://doi.org/10.3389/fmolb.2021.693710
[S11] RCSB PDB existence check for NGAL structures 1NGL / 1L6M / 1X71 / 3FW4 — metadata only via search results ⚠️ structures not downloaded
