# VA Fraud Statistical Framework

Product: MoMo TTT -- Virtual Account (VA)

Purpose: Provide a reusable statistical framework to analyze abnormal VA
activity, justify policy decisions, and evaluate real growth after fraud
mitigation.

------------------------------------------------------------------------

# 1. Analytical Objectives

  -----------------------------------------------------------------------
  Objective               Description             Output
  ----------------------- ----------------------- -----------------------
  Fraud Behavior          Identify abnormal VA    Statistical proof of
  Detection               deposit patterns        abnormal cluster

  Capset Justification    Validate decision to    Defensible policy
                          limit VA deposits       reasoning
                          ≤10/day                 

  Growth Validation       Test whether Feb‑2026   Significance test
                          VA growth is real       results
  -----------------------------------------------------------------------

------------------------------------------------------------------------

# 2. Data Inputs

Required tables:

  Dataset                Description
  ---------------------- ---------------------------
  VA transactions        All deposit transactions
  Cashout transactions   P2P / Napas withdrawal
  User metadata          user_id, merchant flag
  Event logs             deposit entry point usage

Core fields:

user_id\
transaction_time\
transaction_amount\
transaction_type\
entry_point\
device_id

------------------------------------------------------------------------

# 3. Fraud Detection Framework

## 3.1 Distribution Analysis

Compute daily metrics:

transactions_per_user_per_day

Key statistics:

mean\
median\
std deviation\
percentiles (P25, P50, P75, P90, P94, P95, P99)

Goal: Detect heavy‑tail distribution and abnormal spikes.

------------------------------------------------------------------------

## 3.2 Outlier Detection

Tukey IQR rule:

IQR = Q3 − Q1

Outlier threshold:

Q3 + 1.5 × IQR

Extreme outlier:

Q3 + 3 × IQR

Interpretation:

Users above extreme threshold represent abnormal behavioral regime.

------------------------------------------------------------------------

## 3.3 Tail Analysis

Use heavy‑tail diagnostics:

-   Pareto distribution fitting
-   Power‑law slope estimation
-   Lorenz curve
-   Gini coefficient

Goal:

Measure concentration of transactions among top users.

Expected fraud indicator:

Small percentage of users generating disproportionate volume.

------------------------------------------------------------------------

## 3.4 Behavior Segmentation

Segment users by max daily VA transactions:

  Segment      Range
  ------------ --------
  Normal       1--3
  Heavy        4--9
  Suspicious   10--20
  Extreme      \>20

Measure:

transaction contribution per segment.

------------------------------------------------------------------------

# 4. Capset Validation Framework

Goal: Validate limit = 10 VA/day.

Steps:

1.  Calculate cumulative user distribution
2.  Identify percentile breakpoints
3.  Estimate volume reduction under cap scenarios

Simulation:

cap ∈ {10, 15, 20}

For each cap compute:

affected_users\
transactions_removed\
fraud_volume_removed

Decision rule:

Choose cap maximizing fraud reduction while preserving majority users.

------------------------------------------------------------------------

# 5. Fraud Population Isolation

Define clean population:

users with max_daily_va ≤ 9

Purpose:

remove bias caused by fraud cluster.

------------------------------------------------------------------------

# 6. Growth Evaluation Framework

Define periods:

Baseline: Aug‑2025 → Jan‑2026

Test: Feb‑2026 → Mar‑2026

Metrics:

daily_transactions\
daily_unique_users\
daily_GMV

------------------------------------------------------------------------

# 7. Statistical Tests

Recommended methods:

Two‑sample t‑test

Mann‑Whitney U test

Bootstrap mean difference

Interrupted time‑series analysis

Hypothesis:

H0: Feb‑2026 growth = historical baseline

H1: Feb‑2026 growth \> baseline

Significance level:

α = 0.05

------------------------------------------------------------------------

# 8. Expected Outputs

Analysis should produce:

1.  Fraud distribution model
2.  Capset impact simulation
3.  Clean population growth test
4.  Executive summary of findings
