# References Ledger — legitimately used sources

> **Master register:** the complete audited source list for the whole pipeline
> (literature + software + cluster + corrections) lives in
> [`docs/REFERENCES.md`](../docs/REFERENCES.md). This ledger is the research-run
> working log that feeds it — keep both in sync.

Only sources **actually opened and used** during a deep search run belong here.
Each entry records which run it came from. Never add a source that was not consulted.

Format:
`- [run YYYY-MM-DD <run-id>] Title — URL — (used for: <why>)`

---

> Imported 2026-09-04 from the AI_setup deep-search environment (`CliffVale`
> research setup). The two 2026-09-03 runs below are historical records; the
> matching reports live in `research/reports/`. **Future runs append here** —
> never pre-populate with sources you did not consult.

## 2026-09-03 · aptamer-biosensor-deepsearch
- Buglak et al. 2020, Methods and Applications of In Silico Aptamer Design and Modeling, IJMS 21(22):8420 — https://www.mdpi.com/1422-0067/21/22/8420 — (canonical workflow: structure → docking → MD)
- Lee 2023, Design and Prediction of Aptamers Assisted by In Silico Methods — https://pmc.ncbi.nlm.nih.gov/articles/PMC9953197/ — (workflow order; AutoDock4 vs Vina pocket guidance)
- Rodríguez Serrano et al. 2022, Prediction of Aptamer–Small-Molecule Interactions, JCIM 62(19):4799 — https://pubs.acs.org/jcisd8/article/62/19/4799/850186 — (docking for aptamer–small-molecule)
- Nguyen et al. 2024, Truncations and in silico docking to enhance aptamer biosensor analytical performance — https://www.sciencedirect.com/science/article/pii/S0956566324006869 — (docking in biosensor workflow)
- Sabbih 2023, A computational approach for the discovery of aptamers for protein targets (UTC thesis) — https://scholar.utc.edu/cgi/viewcontent.cgi?article=1963&context=theses — (3-step in-silico workflow)
- iGEM Aptamers Hub, Computational Tools — https://aptamershub.wordpress.com/computational-tools/ — (tool list: AutoDock Vina, GROMACS, RNAfold, FASTAptamer)
- virtualscreenlab/AptaFold — https://github.com/virtualscreenlab/AptaFold — (sequence→3D→docking workflow)
- AptaBLE (bioRxiv 2026.01.06.698056) — https://www.biorxiv.org/content/10.64898/2026.01.06.698056v1.full-text — (deep-learning de-novo aptamer design)
- AptaBLE (OpenReview PDF) — https://openreview.net/pdf/eea94ba98c27853039118830b7a5c0b8223f76fb.pdf — (binding prediction across protein targets)
- AptaGPT (bioRxiv 2024.05.23.594910) — https://www.biorxiv.org/content/10.1101/2024.05.23.594910v1.full-text — (generative aptamer sequence design)
- iGEM MADRID UCM 2019, Aptamer folding — https://2019.igem.org/Team:MADRID_UCM/aptamer-folding.html — (3D folding rationale)
- COMSOL blog, Sensing the Bio in Biosensor Design with a Simulation App — https://www.comsol.com/blogs/sensing-the-bio-in-biosensor-design-with-a-simulation-app — (biosensor simulation apps)
- COMSOL paper, Numerical Simulation-Driven Design of Nanophotonic Biosensors — https://www.comsol.com/paper/numerical-simulation-driven-design-of-nanophotonic-biosensors-121751 — (Wave Optics Module for biosensors)
- COMSOL paper, Rapid Prototyping of Biosensing SPR Devices using COMSOL-MATLAB — https://www.comsol.com/paper/rapid-prototyping-of-biosensing-surface-plasmon-resonance-devices-using-comsol-matlab-software-6519 — (COMSOL–MATLAB SPR workflow)
- Ayache 2024, SPR biosensor for bacteria and virus detection: a COMSOL Multiphysics simulation — https://synsint.com/index.php/synsint/article/view/196 — (SPR COMSOL simulation)
- Villarim et al. 2023, SPR-Based Biosensor simulation tool, Coatings 13(3):546 — https://www.mdpi.com/2079-6412/13/3/546 — (open SPR simulation tool)
- Ruiz-Ciancio et al. 2023, AptamerRunner — https://pmc.ncbi.nlm.nih.gov/articles/PMC10680646/ — (structure prediction + clustering)
- Climaco et al. 2025, GMfold — https://www.sciencedirect.com/science/article/pii/S0025556425001117 — (high-throughput secondary structure)
- FASTAptamer — https://github.com/FASTAptamer/FASTAptamer — (SELEX HTS analysis)
- CMCDD/T_SELEX — https://github.com/CMCDD/T_SELEX — (RNA aptamer library generation + structure prediction)
- DTU-Denmark iGEM 2023, AptaLoop/FluoroLoop software — https://2023.igem.wiki/dtu-denmark/software — (aptamer design pipeline example)

## 2026-09-03 · ngal-na53-gromacs-litreview
- [Hong X et al. 2019] Development of a novel ssDNA aptamer targeting NGAL…, J Transl Med 17:204 (full text read via Europe PMC XML) — https://europepmc.org/article/PMC/PMC6582607 — (NA53 identity, sequence, Kd 32.52 nM, UNAFold conditions 25 °C/0.1 M Na+/1 mM Mg2+)
- [Kilgour M et al. 2021] E2EDNA: Simulation Protocol for DNA Aptamers with Ligands, JCIM 61(9):4139 — https://pmc.ncbi.nlm.nih.gov/articles/PMC9536994/ — (hierarchical aptamer fold pipeline: 2D → 3D → all-atom MD validation; brute-force folding infeasible)
- [GROMACS user contributions] Force-field ports incl. amber99bsc1 (parmbsc1) & amber14sb_OL15 (corrected Na+ params) — https://www.gromacs.org/user_contributions.html — (verified GROMACS DNA FF availability + citations)
- [GROMACS 2024.3 manual] Force fields in GROMACS — https://manual.gromacs.org/2024.3/user-guide/force-fields.html — (no native bsc1; CHARMM36 mdp settings; supported AMBER list)
- [NCHC software team] GROMACS quick usage guide (Taiwania-2, Slurm, 2023.4 module + 2022.1/2023.2 Singularity containers) — https://hackmd.io/@nchc-software/B1iK3ZTUF — (HPC execution layer: sbatch patterns, --gres=gpu, singularity --nv, gp1d)
- [K-Dense-AI/scientific-agent-skills] README + skills/molecular-dynamics/SKILL.md — https://github.com/K-Dense-AI/scientific-agent-skills — (methodology base: min→NVT→NPT→production; nucleic acids → bsc1/TIP3P)
- [PubMed esummary PMID 31215436] Hong 2019 citation record (DOI 10.1186/s12967-019-1955-7) — NCBI eutils — (citation + DOI pinning)
- [Crossref API] DOI 10.1186/s12967-019-1955-7 record (J Transl Med 17:204, 2019-06-18) — https://api.crossref.org/works/10.1186/s12967-019-1955-7 — (metadata verification; corrected the -0 guess from truncated ESM URL)
- [Semantic Scholar API] Citation graph of Hong 2019 DOI — retrieved 2026-09-03 (metadata only) — (no published NA53 MD found; downstream works are biosensor papers)
- ⚠️ screened only (metadata/snippet, not read in full): Sengar 2021 oxDNA Primer Front Mol Biosci 8:693710; RCSB PDB entries 1NGL/1L6M/1X71/3FW4

## 2026-09-04 · aptamer-bibliography-analysis (67-ref protocol bibliography)
**Opened & read (full/abstract content extracted into the report):**
- Ochoa S, Milam VT 2025, Direct Modeling of DNA and RNA Aptamers with AlphaFold 3, ACS Synth Biol 14(8):3049–3064, DOI 10.1021/acssynbio.5c00196 — https://pmc.ncbi.nlm.nih.gov/articles/PMC12362623/ — (AF3 for aptamer 3D: GQ/pseudoknot OK; PDB aptamer scarcity 117 DNA/232 RNA; training-bias limits)
- Ropii B et al. 2024, Molecular interaction of six ssDNA aptamers to cardiac troponin I (docking + MD), PLoS ONE 19(5):e0302475 — https://doi.org/10.1371/journal.pone.0302475 — (mFold→RNAComposer T→U surrogate→relax 100 ns→dock; electrostatics-driven binding)
- Dans PD et al. 2017, How accurate are accurate force-fields for B-DNA?, Nucleic Acids Res 45(7):4217–4230, DOI 10.1093/nar/gkw1355 — https://pmc.ncbi.nlm.nih.gov/articles/PMC5397185/ — (only bsc1/bsc0OL15 predictive multi-µs; parm99-era DNA unreliable → evidence for FF switch R2)
- Bian Y et al. 2018, Fast-folding pathways of the TBA G-quadruplex via MSM, Biophys J 114(7):1529–1538, DOI 10.1016/j.bpj.2018.02.021 — https://pmc.ncbi.nlm.nih.gov/articles/PMC5954565/ — (cMD cannot fold even 15-nt aptamer; advanced sampling + MSM needed → validates folded-input design)
- Ropii B et al. 2023, Assessment of MD results of 3D RNA aptamer structure prediction, PLoS ONE 18(7):e0288684 — https://doi.org/10.1371/journal.pone.0288684 — (RNAComposer ~1.7 Å; CHARMM36/TIP3P/1.2 nm/100 ns protocol; MD forms noncanonical loop H-bonds; cluster to pick representative)
- GROMACS manual 2026.3, Getting good performance from mdrun — https://manual.gromacs.org/current/user-guide/mdrun-performance.html — (metrics incl. Matom·steps/s; AVX2>AVX512 on GPU runs; 4 fs mass-repartition; GPU-resident nstcalcenergy/nstlist tuning)
**Screened only (title/venue metadata — no content claims):** the remaining 61 entries of the protocol bibliography (catalogued by domain tier in the report).
**Blocked (attempted, not opened):** ACS pages (#1/#13/#24/#26/#32/#50), PubMed #4 (cookie wall), bioRxiv #25 (403) — do not cite as read.