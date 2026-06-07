# Review log: bridges/QEF_DESIGN/amz/reviews.bridge.yaml

**Bridge**: QEF_DESIGN / amz / reviews
**Source**: 147 xlsx files across 12 PL subdirs (`amazon_reviews/**/*`)
**Target**: `df_amz_reviews___raw`
**Spectra change**: dashboard-presence-verification (active) — addresses #607
**Triggering issue chain**: #607 → #595 → #601 (closed) → #368 (original 5-PL fix)

## Convergence Protocol

This log records iterations of the self-converging review loop per /glue-bridge skill Step 6c-6d. Final verdict line at bottom indicates ship-readiness.

Reviewers per MP102 v1.3:
- **codex-cli** — cross-model independent verification (gpt-5.5, xhigh reasoning)
- **claude-correctness** — data semantics, MP160 mechanical enumeration, business-semantic spot-check
- **claude-security** — value tampering, governance gates, fingerprint integrity
- **claude-devils-advocate** — rebut other reviewers' PASS/LOW; systemic blind spots

Three terminators:
- **CONVERGED** — `findings.critical == 0 && high == 0` AND every remaining MEDIUM/LOW has `findings_resolutions:` rationale
- **PLATEAUED** — `findings_hash[N] == findings_hash[N-1]` (stuck two iters)
- **DIMINISHING** — N+1 only adds SUGGESTION-level findings

Anti-oscillation: `findings_count[N] > findings_count[N-1]` triggers ROLLBACK to N-1 state.


---

## Iteration 1 - 2026-05-10T05:12:23Z

**Reviewers**: codex, correctness, security, devils_advocate

**Findings**: 37 (8 CRITICAL / 10 HIGH / 7 MEDIUM / 6 LOW / 6 SUGGESTION)

**Findings hash**: 525a5b2f3625c275e35ebe450371014e2a55ef1e6438f67a710cd57eddb653ab

| ID  | Severity   | Source              | Rule       | Summary                                |
|-----|------------|---------------------|------------|----------------------------------------|
|   1 | HIGH       | codex               |            | Reviewer: codex-cli @ gpt-5.5 (x reaso |
|   2 | CRITICAL   | codex               |            | > **NOTE**: Structured findings recons |
|   3 | CRITICAL   | codex               |            | - Findings: 5 total (3 / 1 / 0 / 0 / 1 |
|   4 | CRITICAL   | codex               |            | | X-1 | | YAML 1.1 boolean footgun | B |
|   5 | CRITICAL   | codex               |            | | X-2 | | derive_from sha256 not imple |
|   6 | CRITICAL   | codex               |            | | X-3 | | Vine value_map missing + 106 |
|   7 | HIGH       | codex               | MP159      | | X-4 | | customer_id from display nam |
|   8 | SUGGESTION | codex               | MP160      | | X-5 | | MP160 equality + fingerprint |
|   9 | CRITICAL   | correctness         |            | - Findings: 9 total (0 / 2 / 4 / 2 / 1 |
|  10 | HIGH       | correctness         | MP154      | | C-1 | | MP154 / value_map BOOLEAN co |
|  11 | HIGH       | correctness         |            | | C-2 | | review_id collision via sha2 |
|  12 | MEDIUM     | correctness         | MP160      | | M-1 | | MP160 vs canonical platform  |
|  13 | MEDIUM     | correctness         | MP163      | | M-2 | | MP163 / sentinel discipline  |
|  14 | MEDIUM     | correctness         |            | | M-3 | | Multi-ASIN-per-file business |
|  15 | MEDIUM     | correctness         | MP163      | | M-4 | | customer_id privacy + unique |
|  16 | LOW        | correctness         |            | | L-1 | | BOM-prefixed first column he |
|  17 | LOW        | correctness         |            | | L-2 | | review_date format trust | B |
|  18 | SUGGESTION | correctness         |            | | S-1 | | Required-field coverage chec |
|  19 | CRITICAL   | security            |            | - Findings: 2 total (0 / 0 / 1 / 1 )   |
|  20 | MEDIUM     | security            |            | | S-1 | | PII / GDPR | `customer_id` p |
|  21 | LOW        | security            |            | | S-2 | | Defense-in-depth (input trus |
|  22 | MEDIUM     | security            |            | - **Q5**: **Yes — flag as (S-1 above). |
|  23 | HIGH       | devils_advocate     |            | - Findings: 8 total (2 CRIT / 3 / 1 ME |
|  24 | CRITICAL   | devils_advocate     |            | | D-1 | | systemic-blind-spot | **Lega |
|  25 | HIGH       | devils_advocate     | MP163      | | D-2 | | systemic-blind-spot | **Per- |
|  26 | HIGH       | devils_advocate     |            | | D-3 | | upgrade-attempt | **Upgrade  |
|  27 | HIGH       | devils_advocate     |            | | D-4 | | upgrade-attempt | **Upgrade  |
|  28 | MEDIUM     | devils_advocate     | MP163      | | D-5 | | systemic-blind-spot | **`Sys |
|  29 | LOW        | devils_advocate     |            | | D-6 | | upgrade-attempt | **Decline  |
|  30 | SUGGESTION | devils_advocate     | MP161      | | D-7 | | family-level | **Spot-check  |
|  31 | SUGGESTION | devils_advocate     |            | | D-8 | | systemic-blind-spot | **No r |
|  32 | LOW        | devils_advocate     |            | - **correctness L-1 (BOM)** → **NOT up |
|  33 | HIGH       | devils_advocate     |            | - **correctness L-2 (date format trust |
|  34 | HIGH       | devils_advocate     |            | - **security S-2 (value_map exhaustive |
|  35 | SUGGESTION | devils_advocate     | MP160      | - **codex X-5 PASS (MP160 + fingerprin |
|  36 | LOW        | devils_advocate     |            | - **Spot-check finding from `product_a |
|  37 | SUGGESTION | devils_advocate     | MP162      | - **MP162 ship-readiness ladder L4-L5  |