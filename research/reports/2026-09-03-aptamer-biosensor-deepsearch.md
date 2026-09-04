# Aptamer Simulation for Biosensor Development — Toolchain Deep Search

> **Date:** 2026-09-03 · **Log:** research/deepsearch.log · **Run type:** deepsearch (validation run)
> *(Historical report imported 2026-09-04 into GROMACS_NA53's Research SOP.)*
> **Question:** Which computational tools and workflows help with aptamer simulation for biosensor development research — and which of them should be integrated into our deep search setup?
> **Sub-questions:**
> 1. What is the canonical in-silico aptamer development workflow (stages and order)?
> 2. Which open-source tools cover each stage (folding, 3D structure, docking, MD, ML design)?
> 3. Which tools model the biosensor level (SPR / electrochemical / COMSOL)?
> 4. Which of these map onto skills/tools we can integrate now vs. run externally?

## Summary
Aptamer development in silico follows a well-established pipeline: **sequence → secondary
structure → tertiary structure → aptamer–target docking → MD validation**, increasingly
capped by **ML/deep-learning sequence design** (reviews by Buglak 2020 and Lee 2023 agree on
this order). At the biosensor level, **COMSOL Multiphysics** is the dominant tool for
SPR/electrochemical/nanophotonic sensor response modeling, with a COMSOL–MATLAB workflow
used for rapid prototyping. For our setup, the immediately integrable layer is the
**methodology + bioinformatics skills** (biopython, folding/docking tool knowledge, ML
design tools such as AptaFold/AptaBLE/AptaGPT) — heavy MD (GROMACS/AMBER) and COMSOL remain
external tools we orchestrate around, not run inside the agent.

## Evidence

| # | Claim | Evidence / source | Confidence |
|---|-------|-------------------|------------|
| 1 | Canonical workflow is: structure prediction → docking → MD simulation | Buglak et al. 2020, *Methods and Applications of In Silico Aptamer Design and Modeling*, IJMS 21(22):8420 — https://www.mdpi.com/1422-0067/21/22/8420 | high |
| 2 | Same workflow confirmed: secondary structure → tertiary optimization → docking | Lee 2023, *Design and Prediction of Aptamers Assisted by In Silico Methods*, PMC9953197 — https://pmc.ncbi.nlm.nih.gov/articles/PMC9953197/ | high |
| 3 | AutoDock Vina suits polar binding pockets; AutoDock4 suits hydrophobic/non-polar pockets | Lee 2023 (PMC9953197) | high |
| 4 | Docking can be used to screen/truncate aptamers and optimize analytical performance of aptamer biosensors | Nguyen et al. 2024, *Truncations and in silico docking to enhance the analytical performance of aptamer biosensors*, Biosens. Bioelectron. (S0956566324006869) — https://www.sciencedirect.com/science/article/pii/S0956566324006869 | high |
| 5 | Tertiary structure + docking for aptamer–small-molecule interactions is a practical in-silico route | Rodríguez Serrano et al. 2022, JCIM 62(19):4799 — https://pubs.acs.org/jcisd8/article/62/19/4799/850186 | medium |
| 6 | AptaFold: open-source Python3 workflow from oligonucleotide sequence → 3D → docking with DNA/RNA aptamers | virtualscreenlab/AptaFold — https://github.com/virtualscreenlab/AptaFold | high (repo exists; per-version reliability not independently benchmarked) |
| 7 | AptaBLE: deep-learning platform for de-novo aptamer design; sequence-based binding prediction across protein targets | AptaBLE bioRxiv 2026.01.06.698056 — https://www.biorxiv.org/content/10.64898/2026.01.06.698056v1.full-text ; OpenReview PDF — https://openreview.net/pdf/eea94ba98c27853039118830b7a5c0b8223f76fb.pdf | medium (preprint) |
| 8 | AptaGPT: generative pre-trained transformer accelerates high-affinity aptamer sequence generation | AptaGPT bioRxiv 2024.05.23.594910 — https://www.biorxiv.org/content/10.1101/2024.05.23.594910v1.full-text | medium (preprint) |
| 9 | FASTAptamer: standard open-source tool for high-throughput sequencing analysis of aptamer SELEX pools | iGEM Aptamers Hub Computational Tools — https://aptamershub.wordpress.com/computational-tools/ ; https://github.com/FASTAptamer/FASTAptamer | high |
| 10 | GMfold: high-throughput DNA aptamer secondary-structure determination via subgraph matching | Climaco et al. 2025 — https://www.sciencedirect.com/science/article/pii/S0025556425001117 | medium (new) |
| 11 | AptamerRunner: accessible aptamer structure prediction + clustering with visual networks | Ruiz-Ciancio et al. 2023, PMC10680646 — https://pmc.ncbi.nlm.nih.gov/articles/PMC10680646/ | medium |
| 12 | T_SELEX: Python package for RNA aptamer library generation + secondary/tertiary structure and RNA–RNA interaction prediction | CMCDD/T_SELEX — https://github.com/CMCDD/T_SELEX | medium |
| 13 | RNAfold (ViennaRNA) is the main MFE secondary-structure tool (suboptimal structures supported) | iGEM Aptamers Hub Computational Tools — https://aptamershub.wordpress.com/computational-tools/ | high |
| 14 | COMSOL is the leading platform for biosensor multiphysics modeling (SPR, nanophotonic, electrochemical); COMSOL–MATLAB link used for rapid SPR device prototyping | COMSOL blog *Sensing the Bio in Biosensor Design with a Simulation App* — https://www.comsol.com/blogs/sensing-the-bio-in-biosensor-design-with-a-simulation-app ; COMSOL paper *Rapid Prototyping of Biosensing SPR Devices using COMSOL-MATLAB* — https://www.comsol.com/paper/rapid-prototyping-of-biosensing-surface-plasmon-resonance-devices-using-comsol-matlab-software-6519 | high |
| 15 | COMSOL Wave Optics Module used to design/optimize nanophotonic biosensors | COMSOL paper *Numerical Simulation-Driven Design of Nanophotonic Biosensors* — https://www.comsol.com/paper/numerical-simulation-driven-design-of-nanophotonic-biosensors-121751 | high |
| 16 | SPR biosensor response can be fully simulated in COMSOL (e.g., bacteria/virus detection) | Ayache 2024, SynSint — https://synsint.com/index.php/synsint/article/view/196 | high |
| 17 | An interactive open simulation tool for SPR biosensors exists (Villarim 2023) | Villarim et al. 2023, Coatings 13(3):546 — https://www.mdpi.com/2079-6412/13/3/546 | medium |
| 18 | A documented 3-step workflow for in-silico aptamer discovery against protein targets | Sabbih 2023 (UTC thesis) — https://scholar.utc.edu/cgi/viewcontent.cgi?article=1963&context=theses | medium (thesis) |
| 19 | iGEM DTU aptamer design pipeline (AptaLoop/FluoroLoop) covers design → secondary → tertiary prediction | DTU-Denmark iGEM 2023 software — https://2023.igem.wiki/dtu-denmark/software | medium (student project) |

## Gaps
- **AptaBLE** and **AptaGPT** are preprints — claims (binding prediction, generative quality) not yet independently benchmarked. ⚠️
- **MD stage** (GROMACS/AMBER/NAMD) requires HPC and force-field expertise; we did not verify specific aptamer MD protocols in this run (known limitation of this pass).
- Relative performance of AptaFold vs. AlphaFold3/RNAComposer for 3D prediction was not compared in this pass.
- No verified numbers for docking accuracy of AutoDock Vina vs HADDOCK on DNA/RNA–protein complexes in this pass.

## Sources actually used
<All of the above — full list appended to research/REFERENCES.md.>

## Next steps / recommended actions
1. **Integrate now (in progress):** register science skills — biopython, experimental-design, statistical-power, statistical-analysis, uncertainty-and-units, scientific-visualization, matplotlib, seaborn, scikit-learn, statsmodels, sympy, exploratory-data-analysis — plus workflow skills (ponytail, caveman-commit/review, brainstorm, markdown-mermaid-writing).
2. **Document external tools** in the workflow spec (done in research/WORKFLOW.md §domain pipeline): AptaFold, FASTAptamer, GMfold, T_SELEX, AptaBLE/AptaGPT (ML), GROMACS/AMBER (MD), COMSOL (biosensor).
3. **Next validation run:** deep-dive one stage (e.g., "AutoDock Vina vs HADDOCK for DNA aptamer–protein docking") to exercise the pipeline end-to-end with a single-tool focus.
4. Optionally clone AptaFold/T_SELEX for local use when sequence work begins; add as a documented optional component.