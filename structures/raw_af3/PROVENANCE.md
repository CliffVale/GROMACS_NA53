# NA53 AF3 Structure — Provenance Record

**Source:** AlphaFold 3 (server, `alphafoldserver` dialect v3), job 2026-09-04_19:14
**Input:** `job_request.json` — the canonical 75-nt NA53 DNA sequence (Hong et al. 2019), single chain, count 1
**Chosen model:** `model_0` (best ranking_score 0.19, tied with model_1; model_2=0.18, model_3=0.18, model_4=0.17)
**Files here:** raw model_0 mmCIF, summary confidences, full per-residue data, job request

## Confidence caveat (read before interpreting anything)
pTM = 0.19 and iPTM = None. This is **expected and NOT a defect signal** for an
unbound, 75-nt, mostly single-stranded DNA aptamer: AF3's pTM is calibrated for
globular proteins with dense tertiary contacts. An ssDNA aptamer in free solution
has few long-range contacts, so pTM is intrinsically low and not interpretable as
"wrong model". What matters for the pipeline:
- `fraction_disordered: 0.0`, `has_clash: 0.0` — no clashes, no disordered residues
- 75 residues, sequence-identical to the canonical FASTA (validated)
- All nucleotides complete (20–21 heavy atoms each) → pdb2gmx-ready after staging

**Role in the project:** AF3 provides the *starting* conformation; the MD pipeline
(EM → NVT → NPT → production) is the refinement/equilibration tool that relaxes
and samples the aptamer ensemble. Do not interpret the raw AF3 fold as the
"answer" — treat it as the initial coordinates.

## Staging transform applied (documented in validate_na53_pdb.py)
- mmCIF atom_site → PDB records (1544 atoms; OP3 gamma-phosphate of the AF3
  5'-triphosphate dropped → amber-standard 5'-monophosphate `DA5` terminus)
- Residues renumbered contiguously 1..75, single chain A
- Output: `structures/NA53_initial.pdb` — BLESSED by `scripts/validate_na53_pdb.py --stage`
