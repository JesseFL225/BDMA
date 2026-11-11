# Publication verification — Mart

Verified 2026-11-11 using R from the repository root.

| Workflow | Executed checks | Result |
|---|---:|---|
| Step 02 preparation | 34 | PASS |
| Step 03 baselines | 35 | PASS |
| Step 04 ridge multinomial | 31 | PASS |
| Step 07 shared evaluation | 56 | PASS |
| Total | 156 | PASS |

All four workflows were rerun using their existing settings and scripts.
Clean data MD5: `6f22afc6b05fe5e65ed8bd583bc5ba68`.
Frozen class CSV MD5: `17839c07abcae6f72254feb584190b79`.
Both hashes and the saved baseline/logistic metrics matched before/after.
Training/validation/test row counts: 33,004 / 5,296 / 5,948. Test outcomes
remained locked. All four saved prediction tables have 5,296 validation rows
and the exact 108-column shared evaluator contract. No 2025 outcome evaluation.
No advanced models other than the existing ridge analysis were run.

Publication includes shared functions, validation/run scripts, dependencies
and usage instructions, fixed target artifacts, 2024 predictions and metrics,
small verification reports, vector PDF figures and Section 5 report text.
No fitted model objects, caches, session files or credentials are included.
Unrelated mart.analysis.R and descriptive PDF working changes are excluded.

See moddeling/README.md for reproduction commands and Oliver's shared API.
See each step README for assumptions, smoothing and retrospective limitations.
