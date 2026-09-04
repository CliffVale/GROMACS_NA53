# 📚 Source Register — Every External Source Used in the GROMACS_NA53 Workflow

**Purpose:** one legitimate, auditable reference file for the *complete* pipeline —
literature, methodology, software, structure databases, and cluster/infrastructure
sources. Anything an AI or reviewer needs to verify a claim in this repo can be
traced from here.

**Legitimacy policy** (repo rule — see `research/REFERENCES.md`): no invented
sources. Every entry below was actually used: opened during deep-search runs,
verified live this session, cited in repo docs, or executed as software/CLI.
Verification is marked per entry; screened-but-not-read items are flagged.

**Primary data** (live SSH/SLURM/CLI outputs, md logs, trial runs) are *evidence*,
not *sources*; they are logged in `memory.md §4` and `research/deepsearch.log`.

Status tags:
- `[L]` opened & read in a research run (research ledger 2026-09-03)
- `[W]` verified live via web/API 2026-09-04
- `[D]` cited in repo docs/configs (metadata pinned/checked 2026-09-04)
- `[B]` canonical basis for config choices (standard method papers; not re-opened)
- `[S]` software / dataset actually installed, built, or run
- `[P]` primary source of a fact verified live in-session

---

## 1. Target system: the NA53 aptamer (primary literature)

| Source | URL | Used for |
|---|---|---|
| `[L][P]` Hong X et al. 2019, "Development of a novel ssDNA aptamer targeting NGAL…", *J Transl Med* **17**:204, DOI 10.1186/s12967-019-1955-7 (full text read via Europe PMC XML) | https://europepmc.org/article/PMC/PMC6582607 · https://doi.org/10.1186/s12967-019-1955-7 · https://api.crossref.org/works/10.1186/s12967-019-1955-7 · PubMed esummary PMID 31215436 | **NA53 identity**: sequence, 20-nt/35-nt architecture, Kd 32.52 nM, UNAFold conditions (25 °C, 0.1 M Na⁺, 1 mM Mg²⁺) |
| `[L]` (screened only) Sengar et al. 2021, oxDNA primer, *Front Mol Biosci* **8**:693710 | https://doi.org/10.3389/fmolb.2021.693710 | oxDNA coarse-grained alternative (screened, not adopted) |

## 2. Aptamer in-silico design & MD methodology (research runs, 2026-09-03)

| Source | URL | Used for |
|---|---|---|
| `[L]` Buglak et al. 2020, Methods and Applications of In Silico Aptamer Design and Modeling, *IJMS* 21(22):8420 | https://www.mdpi.com/1422-0067/21/22/8420 | canonical workflow: structure → docking → MD |
| `[L]` Lee 2023, Design and Prediction of Aptamers Assisted by In Silico Methods | https://pmc.ncbi.nlm.nih.gov/articles/PMC9953197/ | workflow order; AutoDock4 vs Vina pocket guidance |
| `[L]` Rodríguez Serrano et al. 2022, Prediction of Aptamer–Small-Molecule Interactions, *JCIM* 62(19):4799 | https://pubs.acs.org/jcisd8/article/62/19/4799/850186 | docking for aptamer–small-molecule |
| `[L]` Nguyen et al. 2024, Truncations and in silico docking to enhance aptamer biosensor analytical performance | https://www.sciencedirect.com/science/article/pii/S0956566324006869 | docking in biosensor workflow |
| `[L]` Sabbih 2023, A computational approach for the discovery of aptamers for protein targets (UTC thesis) | https://scholar.utc.edu/cgi/viewcontent.cgi?article=1963&context=theses | 3-step in-silico workflow |
| `[L]` iGEM Aptamers Hub, Computational Tools | https://aptamershub.wordpress.com/computational-tools/ | tool list: AutoDock Vina, GROMACS, RNAfold, FASTAptamer |
| `[L]` virtualscreenlab/AptaFold | https://github.com/virtualscreenlab/AptaFold | sequence→3D→docking workflow (candidate for Phase 5) |
| `[L]` AptaBLE (bioRxiv 2026.01.06.698056) + OpenReview PDF | https://www.biorxiv.org/content/10.64898/2026.01.06.698056v1.full-text · https://openreview.net/pdf/eea94ba98c27853039118830b7a5c0b8223f76fb.pdf | deep-learning de-novo aptamer design / binding prediction |
| `[L]` AptaGPT (bioRxiv 2024.05.23.594910) | https://www.biorxiv.org/content/10.1101/2024.05.23.594910v1.full-text | generative aptamer sequence design |
| `[L]` iGEM MADRID UCM 2019, Aptamer folding | https://2019.igem.org/Team:MADRID_UCM/aptamer-folding.html | 3D folding rationale |
| `[L]` COMSOL blog + 2 papers (biosensor simulation, SPR COMSOL–MATLAB) | https://www.comsol.com/blogs/sensing-the-bio-in-biosensor-design-with-a-simulation-app · https://www.comsol.com/paper/numerical-simulation-driven-design-of-nanophotonic-biosensors-121751 · https://www.comsol.com/paper/rapid-prototyping-of-biosensing-surface-plasmon-resonance-devices-using-comsol-matlab-software-6519 | downstream biosensor modeling (context, not this MD pipeline) |
| `[L]` Ayache 2024, SPR biosensor simulation (COMSOL) | https://synsint.com/index.php/synsint/article/view/196 | SPR COMSOL simulation (context) |
| `[L]` Villarim et al. 2023, SPR-based biosensor simulation tool, *Coatings* 13(3):546 | https://www.mdpi.com/2079-6412/13/3/546 | open SPR simulation tool (context) |
| `[L]` Ruiz-Ciancio et al. 2023, AptamerRunner | https://pmc.ncbi.nlm.nih.gov/articles/PMC10680646/ | structure prediction + clustering |
| `[L]` Climaco et al. 2025, GMfold | https://www.sciencedirect.com/science/article/pii/S0025556425001117 | high-throughput secondary structure |
| `[L]` FASTAptamer · CMCDD/T_SELEX · DTU iGEM 2023 AptaLoop | https://github.com/FASTAptamer/FASTAptamer · https://github.com/CMCDD/T_SELEX · https://2023.igem.wiki/dtu-denmark/software | SELEX analysis / library generation / design pipelines (context) |
| `[L][P]` Kilgour et al. 2021, E2EDNA: Simulation Protocol for DNA Aptamers with Ligands, *JCIM* 61(9):4139 | https://pmc.ncbi.nlm.nih.gov/articles/PMC9536994/ | hierarchical fold protocol (2D → 3D → all-atom MD); brute-force folding infeasible → why we need a folded input |
| `[L]` K-Dense-AI/scientific-agent-skills (skills/molecular-dynamics) | https://github.com/K-Dense-AI/scientific-agent-skills | methodology base (min→NVT→NPT→prod; nucleic acids → bsc1/TIP3P) |

## 3. DNA force fields & GROMACS capabilities (cited in repo docs/configs)

| Source | URL | Used for |
|---|---|---|
| `[L]` GROMACS user contributions — force-field ports incl. amber99bsc1 & amber14sb_OL15 | https://www.gromacs.org/user_contributions.html | verified GROMACS DNA FF availability + citations |
| `[L]` GROMACS 2024.3 manual, "Force fields in GROMACS" | https://manual.gromacs.org/2024.3/user-guide/force-fields.html | no native bsc1; CHARMM36 mdp settings; supported AMBER list |
| `[D][W]` Zgarbová et al. 2011 (bsc0), "Toward improved description of DNA backbone…", *JCTC* 7:2886–2902, DOI 10.1021/ct200326x | https://doi.org/10.1021/ct200326x | README row #2 cites this for the AMBER DNA backbone refinement lineage |
| `[D][W]` Ivani et al. 2016 (parmbsc1), "Parmbsc1: a refined force field for DNA simulations", *Nat Methods* 13:55–58, DOI 10.1038/nmeth.3658 | https://doi.org/10.1038/nmeth.3658 | the actual bsc1 paper (candidate FF; see corrections §8) |
| `[D][W]` Lindorff-Larsen et al. 2010, ff99SB-ILDN, *Proteins* 78:1950–1958, DOI 10.1002/prot.22711 | https://doi.org/10.1002/prot.22711 | the **chosen** force field (amber99sb-ildn DNA, per rules.md) |
| `[B]` Jorgensen et al. 1983, TIP3P water, *J Chem Phys* 79:926–935, DOI 10.1063/1.445869 | https://doi.org/10.1063/1.445869 | water model (TIP3P) |
| `[B]` Essmann et al. 1995, smooth PME, *J Chem Phys* 103:8577–8593, DOI 10.1063/1.470117 | https://doi.org/10.1063/1.470117 | PME electrostatics settings |
| `[B]` Bussi et al. 2007, v-rescale thermostat, *J Chem Phys* 126:014101, DOI 10.1063/1.2408420 | https://doi.org/10.1063/1.2408420 | V-rescale T-coupling |
| `[B]` Parrinello & Rahman 1981, *J Appl Phys* 52:7182–7190, DOI 10.1063/1.328693 | https://doi.org/10.1063/1.328693 | Parrinello-Rahman P-coupling |
| `[B]` Hess et al. 1997, LINCS, *J Comput Chem* 18:1463–1472 | https://doi.org/10.1002/(SICI)1096-987X(199709)18:12<1463::AID-JCC4>3.0.CO;2-H | bond constraints (2 fs timestep) |
| `[D]` Abraham et al. 2015, GROMACS, *SoftwareX* 1–2:19–25 | https://doi.org/10.1016/j.softx.2015.06.001 | GROMACS engine (modern canonical citation, README #5) |
| `[D][W]` Yekeen et al. 2023, CHAPERONg, *Comput Struct Biotechnol J* 21, DOI 10.1016/j.csbj.2023.09.024 | https://doi.org/10.1016/j.csbj.2023.09.024 · https://pubmed.ncbi.nlm.nih.gov/37854635/ | automated GROMACS pipeline reference (README #6; journal corrected — see §8) |
| `[D][W]` Díaz-Fernández et al. 2025, "Refinement and Truncation of DNA Aptamers Based on MD Simulations", ChemRxiv, DOI 10.26434/chemrxiv-2025-k5mzk | https://chemrxiv.org/doi/full/10.26434/chemrxiv-2025-k5mzk · https://pubmed.ncbi.nlm.nih.gov/40228078/ | aptamer truncation via MD (README #4) |

## 4. Structure databases & 3D-modeling software (Phase 5 candidates + test inputs)

| Source | URL | Used for |
|---|---|---|
| `[S][P]` RCSB PDB entry **1BNA** — B-DNA dodecamer (Drew et al. 1981, *PNAS* 78:2179–2183, DOI 10.1073/pnas.78.4.2179) | https://www.rcsb.org/structure/1BNA | **test/trial structure** for every end-to-end pipeline run (stand-in until real NA53 model) |
| `[D]` Zhang group **3dDNA** | https://zhanggroup.org/3dDNA | candidate 3D builder (Phase 5) |
| `[D][W]` **w3DNA** (web 3DNA), Rutgers | https://w3dna.rutgers.edu | candidate DNA 3D builder (Phase 5) |
| `[D]` **RNAComposer** | https://rnacomposer.cs.put.poznan.pl/ | ❌ RNA-only — **blocked** for DNA NA53 (rules.md) |
| `[L]` RCSB PDB 1NGL / 1L6M / 1X71 / 3FW4 | https://www.rcsb.org/ | NGAL/lipocalin structures (screened only, not read) |
| `[D]` APTAMD / APTAMD_TUTORIALS (dimassuarez) | https://github.com/dimassuarez/APTAMD · https://github.com/dimassuarez/APTAMD_TUTORIALS | protocol reference (deep-analyzed; RNAComposer/GaMD stages are RNA-oriented) |

## 5. Infrastructure & cluster (Taiwania 3 decision chain)

| Source | URL | Used for |
|---|---|---|
| `[P]` **Taiwania 3 live session** (SSH `u5662994@twnia3.nchc.org.tw`, motd 2026-08-14 policy, `sinfo -s`, `sacctmgr`, `module avail`, `scontrol`) | twnia3.nchc.org.tw (live) | VERIFIED facts in memory.md §4.1: account mst115368, partition ct56 (56 cores, 754 GB), gcc-only modules, GPU partitions restricted/down |
| `[L]` NCHC software team, GROMACS quick usage guide (Taiwania-2, Slurm, 2023.4) | https://hackmd.io/@nchc-software/B1iK3ZTUF | HPC execution patterns (sbatch, --gres=gpu, singularity); **Taiwania-2 reference only** |
| `[W]` NCHC — TWCC 台灣AI雲 **service termination announcement (offline 2026-08-31)** | https://www.facebook.com/nchc.tw/posts/1356983769966414/ | TWCC is no longer an option (docs/HPC_GPU_OPTIONS.md) |
| `[W]` NCHC iService — compute resource requests / Q&A (Taiwania 3, TWCC pricing) | https://iservice.nchc.org.tw/nchc_service/index.php · https://iservice.nchc.org.tw/nchc_service/nchc_service_qa.php?target=54 | GPU rental path on Taiwania 3 via iService |
| `[W]` 台智雲 TWAI (Taiwania 2 commercial, V100) | https://www.twcloud.ai/en_us/products-and-services/gpu-hpc-service/ · https://docs.twcloud.ai/en/docs/user-guides/twcc/twnia2-hpc-cli/overview · https://docs.twcloud.ai/en/docs/user-guides/twcc/twnia2-hpc-cli/queues · https://docs.twcloud.ai/en/docs/user-guides/twcc/twnia2-hpc-cli/compute-resources | GPU fallback platform (V100 via Slurm) |
| `[W]` Taiwania 3 official user manual (使用說明) | https://man.twcc.ai/@twnia3/rJM5qk3Aw (opened 2026-09-04) | prohibited uses (crypto/weapons/cyber → suspension); filesystem layout; queue policy history | docs/TAIWANIA3_ETIQUETTE.md §3 |
| `[W]` Taiwania 3 official FAQ | https://iservice.nchc.org.tw/nchc_service/nchc_service_qa.php?target=118 (opened 2026-09-04) | allocation etiquette: no --mem = whole-node memory; core scatter; job reason codes; requeue/PREEMPTED; sharing | docs/TAIWANIA3_ETIQUETTE.md §5 |
| `[W]` 如何連線到國網中心 (acyang, HackMD) | https://hackmd.io/@acyang/rJTFDZpB0 | 2FA-bypass prohibition (snippet-verified) | docs/TAIWANIA3_ETIQUETTE.md §3 |
| `[W]` NCHC system/general FAQ | https://iservice.nchc.org.tw/nchc_service/nchc_service_qa.php?target=129 | /tmp periodic cleanup on login/transfer nodes (snippet-verified) | docs/TAIWANIA3_ETIQUETTE.md §4 |
| `[W]` NCHC national center (Taiwania 3 overview) | https://www.nchc.org.tw/ | institutional reference |

## 6. Software actually used in runs (installed / executed)

| Item | Version / provenance | Used for |
|---|---|---|
| `[S]` GROMACS (local build) | 2025.3 GPU build at `~/gromacs-2025.3/build` (runtime errors link manual.gromacs.org/current) | all local trials & the clone-and-run test |
| `[S]` GROMACS (cluster pin) | 2024.4 conda-forge in `environment.yml` | Taiwania 3 engine (CPU, thread-MPI) |
| `[S]` conda-forge channel + Miniconda installer | https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh (setup script) | environment bootstrap |
| `[S]` GROMACS source tarball (GPU build path, optional) | https://ftp.gromacs.org/gromacs/gromacs-2024.4.tar.gz | `install_gromacs_gpu.sh` (local machine only) |
| `[S]` Analysis stack (env pins) | MDAnalysis, biopython, numpy, pandas, matplotlib, seaborn, **seqfold** (DNA 2D folding) | 05_visualization.py + Phase-5 structure pipeline |
| `[S]` SLURM tooling | sbatch/squeue/scontrol/sacctmgr/sinfo (Taiwania 3) | submit + monitor |
| `[S]` GitHub Actions (ubuntu-latest, actions/checkout@v4) | https://github.com/features/actions | CI validation |

## 7. Additions 2026-09-04 — aptamer/GROMACS bibliography analysis

Opened & extracted into `research/reports/2026-09-04-aptamer-bibliography-analysis.md`
(full ledger section in `research/REFERENCES.md`):

| Source | URL | Used for |
|---|---|---|
| `[L]` Ochoa & Milam 2025, AF3 for DNA/RNA aptamers, *ACS Synth Biol* 14(8):3049, DOI 10.1021/acssynbio.5c00196 | https://pmc.ncbi.nlm.nih.gov/articles/PMC12362623/ | Phase-5 structure-prediction option (AF3); PDB aptamer-scarcity data |
| `[L]` Ropii et al. 2024 (cTnI ssDNA aptamers, *PLoS ONE* 19:e0302475) | https://doi.org/10.1371/journal.pone.0302475 | ssDNA modeling protocol (mFold→RNA-surrogate→relax→dock) |
| `[L]` Dans et al. 2017 (B-DNA FF accuracy, *NAR* 45:4217, gkw1355) | https://pmc.ncbi.nlm.nih.gov/articles/PMC5397185/ | **evidence for R2**: only bsc1/bsc0OL15 reliable multi-µs → current parm99-era DNA FF is the weak tier |
| `[L]` Bian et al. 2018 (TBA GQ folding MSM, *Biophys J* 114:1529) | https://pmc.ncbi.nlm.nih.gov/articles/PMC5954565/ | folding-sampling infeasibility evidence (validates folded-input design) |
| `[L]` Ropii et al. 2023 (RNA aptamer 3D + MD, *PLoS ONE* 18:e0288684) | https://doi.org/10.1371/journal.pone.0288684 | RNAComposer ~1.7 Å; MD-refines-models; clustering guidance |
| `[L]` GROMACS 2026.3 manual, mdrun performance | https://manual.gromacs.org/current/user-guide/mdrun-performance.html | perf metrics + tuning levers (R5/R6) |

---

## 8. Provenance records (internal — this repo's own lineage)

| Record | Where | Note |
|---|---|---|
| GROMACS_TEEP (trial-run precursor repo) | https://github.com/CliffVale/GROMACS_TEEP | source of validated parameters (1BNA 200 ns, 0.8 nm, 257 ns/day) |
| AI_setup folder (deep-search environment) | local export (`freebuff_s23u_output/AI_setup`) | origin of the Research SOP + seed reports |
| GROMACS_NA53 (this repo) | https://github.com/CliffVale/GROMACS_NA53 | canonical execution source of truth |
| Session transcripts & run log | `research/deepsearch.log`, docs/*, memory.md | audit trail (internal evidence) |

## 8. Corrections & caution notes (found while building this register)

| # | Location | Claim | Corrected record |
|---|---|---|---|
| C1 | README §References row #2 | "AMBER99bsc1: Zgarbová et al. JCTC 2011, 7, 2886" | Zgarbová 2011 is **bsc0**; **bsc1 = Ivani et al. 2016, Nat Methods 13:55**. README row fixed to bsc0; both registered above. |
| C2 | README §References row #6 | "CHAPERONg: Yekeen et al. GigaScience 2023" | Published in **Comput Struct Biotechnol J 2023**, DOI 10.1016/j.csbj.2023.09.024 (PubMed 37854635), not GigaScience. README row fixed. |
| C3 | NA53 sequence | whitespace inside the random region in the publisher XML | typographic artifact; 20/35 architecture confirmed (see research lit review) |

---

*Register assembled 2026-09-04 from the research ledger (research/REFERENCES.md), the repo-wide URL inventory, and live web verification. Append new sources here AND to research/REFERENCES.md when a research run adds them.*
