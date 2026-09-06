# NA53 (anti-NGAL aptamer) — 15 ns all-atom MD pilot: results and interpretation

**Prepared:** 2026-09-06 · **Status:** honest pilot write-up (non-converged single trajectory)
**Companion documents:** `2026-09-06-na53-15ns-run-audit.md` (raw-data corrections) ·
`2026-09-06-na53-15ns-results-superseded.md` (superseded figures, carries correction banner)
**Raw data mirror:** `/run/media/cliff/WD_HDD/GROMACS/NA53_15ns_results/15ns_prod/` (22 `.xvg`,
8 `.png`, `prod.xtc` 1.62 GB, `prod.edr`, `prod.cpt`, `prod.log`); T3
`~/GROMACS_NA53/archive/2026-09-06_15ns_prod/`.

---

## 1. Purpose

NA53 is a 75-nucleotide single-stranded DNA aptamer selected against **NGAL
(neutrophil gelatinase-associated lipocalin)**, a clinical biomarker for acute kidney injury.
The project goal is a defensible, reproducible **all-atom molecular-dynamics picture of NA53's
folding landscape in solution** to support aptamer-based biosensor design (surface
immobilization strategy, exposed epitope architecture, and expected conformational behavior
under assay conditions). This report summarizes the first production-scale simulation obtained
on Taiwania 3 — a **15 ns explicit-solvent trajectory** — states exactly what it does and does
not establish, and interprets the results in biosensor-relevant terms without over-claiming.

---

## 2. System and methods (all parameters verified in `configs/*.mdp`)

| Component | Value |
|---|---|
| Sequence | 75 nt, `structures/NA53.fasta` (canonical, provenance-verified) |
| Starting model | AlphaFold 3 `model_0` (job 2026-09-04_19:14), staged + blessed via `validate_na53_pdb.py --stage` (mmCIF → PDB, 5′-phosphate normalized to the amber `DA5` 5′-OH terminus; pTM 0.19 — expected-low for unbound ssDNA, no clashes/disorder) |
| Force field / water | amber99sb-ildn (DNA) + TIP3P, monovalent Na⁺/Cl⁻ neutralizing + ~0.1 M |
| System size | 290,578 atoms (≈96 k water molecules) |
| Engine | GROMACS 2024.4 (conda-forge), single precision, 56 OpenMP threads, AVX2_256 |
| Protocol | EM (steepest descent) → NVT 100 ps (310 K, positional restraints) → NPT restrained 100 ps → NPT free 500 ps → **production 15 ns** (dt 2 fs; 7,500,000 steps) |
| Ensemble | V-rescale 310.15 K (τ 0.1, two groups) · Parrinello-Rahman 1 bar (τ 2.0) · PME, `rcoulomb`/`rvdw` 0.8 nm, Potential-shift-Verlet, DispCorr EnerPres |
| Production rate | **18.315 ns/day** (1.31 h/ns, 56 cores; no 28→56 scaling gain — memory-bandwidth limited) |
| Analysis | `gmx` suite on-cluster: RMSD, RMSF, gyrate, SASA, hbond (2024 selection syntax), covar/anaeig PCA, gromos clustering (0.2 nm), energy terms (**extracted by name** — see audit); figures re-rendered after correction |

Reproducibility: `run_simulation.sh submit --profile taiwania3_cpu` (clone-and-run, CI-validated);
job `na53_prod 2036720` (finished 2026-09-06 08:45:37 CST), analysis `2036721`.

---

## 3. Results (corrected numbers; 1,501 frames @ 10 ps over 15 ns)

### 3.1 The aptamer forms a stable, partially collapsed globule

| Quantity | mean ± sd | range | final | Interpretation |
|---|---|---|---|---|
| Radius of gyration Rg (nm) | **3.548 ± 0.104** | 3.27–3.86 | 3.46 | Globular-to-elongated compact coil; **far below** the ≈14 nm fully extended chain → real intramolecular collapse |
| SASA (nm²) | 148.5 ± 1.5 | 144.0–153.4 | 145.9 | Solvent-exposed surface stable; no unfolding/refolding events |
| Intra-DNA H-bonds | 70.7 ± 3.7 | 58–83 | 71 | Persistent internal base pairing/stacking network |
| Temperature (K) | 310.14 ± 0.59 | 308.3–312.3 | 310.6 | Thermostat healthy |
| Density (kg/m³) | 988.6 ± 1.6 | 982.8–995.3 | 988.2 | Correct (name-based extraction) |
| Pressure (bar) | 2.0 ± 50.7 | −159…+167 | 61 | Mean ≈ 1 bar target; large instantaneous swings normal for Parrinello-Rahman |
| Potential (kJ/mol) | −4.0902e6 ± 2,358 | −4.097e6…−4.082e6 | −4.0904e6 | Stable deep minimum (±0.06 %) |

Rg and H-bond count are essentially uncorrelated (r = −0.03): compaction is not simply driven
by the internal pairing count on this trajectory. The molecule breathes (Rg ±0.1 nm) around a
compact-elongated ensemble rather than fluctuating between folded and extended states.

### 3.2 Where the flexibility is (biosensor-relevant)

Per-residue RMSF (overall mean 0.52 nm):

- **3′-terminal tail, residues 73–75 (AAG): RMSF 0.96 / 1.19 / 1.43 nm** — the most mobile
  element, persistently solvent-exposed (res 75 SASA 3.82 nm², the highest in the molecule).
- **Secondary flexible patch, residues 31–35 (AAGGG region): 0.66–0.83 nm** — an exposed loop
  (res 33 SASA 2.81 nm²).
- **Rigid core, residues 22–26 (CGTCG…): 0.33–0.38 nm** — the most ordered segment; several
  strongly buried residues (14–15, 18, 47, 66, 28: SASA 1.56–1.74 nm²) sit in the packed core.

Biosensor reading: a **free 3′ tail** is ideal for end-tethering to a sensor surface (thiol/Au or
biotin/avidin immobilization) without disrupting the folded core — a design that leaves the
internal scaffold and the 31–35 loop available for target (NGAL) interaction. This is an
observable hypothesis from the simulation, not yet validated against binding data.

### 3.3 Collective motions

PCA over the DNA atoms: mode 1 carries **35.1 %** of the variance, top-2 ≈ 51 %, top-8 ≈ 85 %.
The motion is dominated by few collective degrees of freedom (typical of a partially structured
oligonucleotide), and PC1 correlates only weakly with Rg (r = +0.20) and H-bond count
(r = +0.30). Cluster analysis (gromos, 0.2 nm cutoff) yields **347 clusters over 1,501 frames —
no cluster exceeds 0.7 % occupancy** (top-5 = 3.7 %, top-10 = 7.1 %): the chain samples a broad,
continuously-connected set of compact-elongated conformations.

### 3.4 Equilibration quality (pre-production)

EM converged (final potential −4.86e6 kJ/mol); NVT held 310.2 K; unrestrained NPT2 equilibrated
at 310.2 K, 988.7 kg/m³, mean pressure 2.7 bar. The production ensemble inherits a properly
equilibrated box.

---

## 4. Honest status: what this trajectory does and does not establish

**Established (robust within this trajectory):**
1. The staged AF3 model is pdb2gmx-valid and the pipeline runs end-to-end on Taiwania 3
   (throughput benchmark: 18.3 ns/day, single-slot 15 ns run, full analysis + figures).
2. Under the amber99sb-ildn/TIP3P model at 310 K, NA53 collapses to a compact-elongated globule
   (Rg ≈ 3.5 nm) with a persistent internal H-bond network and a stable solvent-exposed surface
   over 15 ns — no unfolding, no extended-chain excursions.
3. The 3′ tail (residues 73–75) and an internal patch (31–35) are the flexible, exposed elements;
   a rigid core (≈22–26) and buried residues define a partially packed interior.

**NOT established (must not be claimed):**
- **Convergence.** RMSD was still climbing at 15 ns (1-ns window means rise 0.47 → ≈0.9 nm;
  second-half mean 0.79 nm > first-half 0.70 nm; last-4-ns slope +0.014 nm/ns; final-frame RMSD
  1.03 nm vs the 1.12 nm maximum reached at 13.6 ns). The molecule had not settled into a single
  basin — consistent with 347 clusters and no dominant family.
- **A unique 3D fold.** No representative structure can be called "the NA53 fold" from one
  15 ns run. AF3 pTM 0.19 and the flat MFE prediction (seqfold: no stable stem at 310 K) both
  flag that the unbound aptamer is intrinsically flexible; single-trajectory sampling at the
  sub-µs scale cannot resolve its equilibrium ensemble.
- **Binding epitopes.** NGAL was not present; any statement about the target-binding surface is
  inference from flexibility/burial, not binding simulation.

---

## 5. Interpretation for the biosensing goal

1. **End-immobilization strategy is well supported.** The free 3′ tail is the natural tether
   point; nothing in the simulation suggests tethering there would unfold the core.
2. **Target engagement must be simulated explicitly.** The next scientific step is docking/
   co-simulation of NA53 with NGAL (or the NGAL peptide used in selection) — the 31–35 loop and
   core residues are candidate contact regions to test, not conclusions.
3. **A longer, better-sampled dataset is required for publication-grade claims.** Options, in
   order of cost: (a) 2–3 independent replicas at 50–100 ns (reproducibility of the globule +
   flexibility pattern); (b) a genuine 100 ns via two 95-h RESTART segments (~6 days CPU); (c)
   enhanced sampling (replica exchange / metadynamics on Rg or end-to-end distance) if free-energy
   surfaces are needed; (d) a GPU partition if one becomes available (5–10× rate).

---

## 6. Figures

Corrected figures (energy terms + summary dashboard re-rendered from name-extracted data) are in
the archive mirror `…/15ns_prod/*.png`: `rmsd`, `rmsf`, `gyrate`, `sasa`, `hbonds`, `pca`,
`energy_terms`, `summary_dashboard`. Note the x-axis of the archived figures reflects the actual
**15 ns** span.

---

## 7. References (source register: `docs/REFERENCES.md`)

1. Hong et al. — NA53 aptamer selection against NGAL (primary source; sequence + UNAFold 2D
   context, 25 °C/0.1 M Na⁺/1 mM Mg²⁺).
2. AlphaFold 3 job 2026-09-04_19:14 (`structures/raw_af3/` provenance: model_0, pTM 0.19,
   has_clash 0, disordered 0).
3. Ivani et al., *Nat. Methods* 2016 (bsc1) / Dans et al., *Nat. Commun.* 2017 — force-field
   accuracy evidence (parmbsc1/OL15 flagged for future FF validation, Q7 in memory.md).
4. GROMACS 2024.4 (conda-forge) — engine.
5. seqfold (MFE 2D, pip dependency) — used only as the cross-check that reported no stable stem
   at 310 K.

*This report was written from raw `.xvg` numbers recomputed during the 2026-09-06 audit; all
values are traceable to files in the archive mirror listed in §1.*
