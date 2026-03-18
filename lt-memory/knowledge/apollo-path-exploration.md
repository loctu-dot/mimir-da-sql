# Apollo Path Exploration — Domain Knowledge

## Product Overview

Path Exploration là tính năng phân tích hành trình user trong MoMo app, thuộc nền tảng Apollo. Cho phép PO/DA/Stakeholders truy vết user journey, khám phá luồng phổ biến/hiếm, phân tích conversion, và segmentation. Lấy cảm hứng từ GA4 nhưng vượt trội ở: chuyển node type linh hoạt tại mỗi step, custom segment từ Apollo/Trackify, 4 dimension (miniapp, screen, event, service).

Target accuracy: >90% (overview purpose, không cần exact). Sampling 10% user/ngày để giảm 90% compute cost.

## Tables

| Table | Dataset | Content | Rows (2026-02-28) |
|-------|---------|---------|-------------------|
| `apollo_session_array_bq_full` | BU_FI | All user sessions with array columns (all_apps, all_screens, all_events, all_services) | 38.5M sessions, 3.91M users |
| `apollo_session_array_bq_sample` | BU_FI | 10% sampled users, same schema | 3.83M sessions, 352K users |
| `apollo_path_full_validate_platform` | BU_FI | Pre-computed 9-step path for ONE starting point only | 4.72M rows, 2.95M users |
| `apollo_path_sample_validate_platform` | BU_FI | Same, sample only | 462K rows, 275K users |
| `apollo_path_sampling_segment` | REPORT | Sampling segment definition (user demographics) | 384K rows |
| `raw_apollo_path_event` | BU_FI | Raw events before sessionization | 467M rows |
| `apollo_path_base_event` | BU_FI | Filtered/deduped events | 178M rows |

## Data Pipeline (5 steps)

1. **Event Preparation** — Extract raw events, forward-fill empty fields within session
2. **Sessionization** — 30-minute inactivity rule (industry standard, same as GA4)
3. **Path Aggregation** — Group events per session into 4 parallel arrays (all_apps, all_screens, all_events, all_services)
4. **Consecutive Dedup** — Remove repeated identical nodes (A→A→B→C becomes A→B→C). Critical because miniapp is parent layer generating many child events.
5. **Path Prefix Generation** — Generate all prefixes for interactive drill-down (ARRAY_SLICE)

## Gotchas

- `validate_platform` tables are pre-filtered to a SINGLE starting point (e.g., vn.momo.platform). Do NOT use for multi-starting-point analysis. Use `session_array` tables instead.
- `session_array` has `all_apps[SAFE_OFFSET(0)]` as the starting miniapp. Many sessions start with "empty" — exclude these for meaningful analysis.
- `user_id` and `session_id` have PII policy tags but are accessible for COUNT(DISTINCT) on BU_FI tables.
- `device_os` is empty in session_array samples — may be a data pipeline issue.
- Sampling rate target = 10%. Observed rate on 2026-02-28 = 9.0% (351,840 / 3,910,498) — the gap is due to ETL filtering/dedup, not sampling method. Use dynamic scale factor = 1/actual_rate when comparing to compensate.
- Path Exploration supports Starting AND Ending point selection — user can trace forward or backward.
- Node type switching: when choosing Screen at step 3 after Miniapp at step 2, it shows screens the user visited after entering that miniapp (can be screens within or outside the miniapp).
- Segments from Apollo/Trackify can be joined directly for targeted path analysis.

## Validation Results (2026-02-28)

- Coverage: 100% for paths ≥ 1K users
- Weighted gap: 6.08% (threshold < 10%)
- φ dispersion: 33.26 overall but 1.18 for low-traffic miniapps. Top 3 miniapps (home_momo, compose-old, bank) contribute 89.3% of Σ(Z²).
- Z-test is overpowered at large n. Use effect size (% gap) instead of Z-score for miniapps with >100K users.
- Margin of Error with 352K sample = ±0.17% at 95% confidence — far exceeds requirements.

## Reports

- **Full report (v2):** `docs/research/apollo_path_exploration_report_v2.md` — Phần 1: Overview + Phần 2: Data Quality
- **Original report:** `docs/research/apollo_sampling_validation_report_2026-02-28.md`
- **HTML dashboard:** `data/output/apollo_sampling_validation_2026-02-28.html`

## Methodology Reference

- Framework (Vietnamese): `docs/research/validate-report/apollo_sampling_validation_framework.md`
- SQL models + guardrails (Vietnamese): `docs/research/validate-report/apollo_sampling_sql_models_guardrails.md`
