# VA Growth Significance Test Playbook

Purpose: Provide step‑by‑step execution guide for validating whether VA
growth after Feb‑2026 is statistically significant.

------------------------------------------------------------------------

# 1. Step 1 -- Data Preparation

Extract daily dataset.

Fields:

date\
user_id\
va_transactions\
va_gmv

Aggregation:

transactions_per_user_day

------------------------------------------------------------------------

# 2. Step 2 -- Remove Fraud Cluster

Filter rule:

max_daily_va_transactions ≤ 9

Rationale:

Remove extreme users (\>P94) identified during fraud investigation.

------------------------------------------------------------------------

# 3. Step 3 -- Construct Metrics

Daily metrics:

  Metric   Description
  -------- ----------------------------
  DAU_VA   Unique users depositing VA
  TXN_VA   Number of transactions
  GMV_VA   Total deposited value

------------------------------------------------------------------------

# 4. Step 4 -- Baseline Construction

Baseline window:

Aug‑2025 → Jan‑2026

Compute:

mean_daily_transactions\
std_daily_transactions

------------------------------------------------------------------------

# 5. Step 5 -- Hypothesis Testing

Test period:

Feb‑2026 → Mar‑2026

Hypothesis:

H0: mean_test ≤ mean_baseline\
H1: mean_test \> mean_baseline

Use:

two‑sample t‑test

or

Mann‑Whitney U (robust).

------------------------------------------------------------------------

# 6. Step 6 -- Effect Size

Compute:

lift = (mean_test − mean_baseline) / mean_baseline

Also calculate:

95% confidence interval.

------------------------------------------------------------------------

# 7. Step 7 -- Robustness Checks

Perform additional checks:

-   Bootstrap mean difference
-   Weekly aggregation validation
-   Seasonality adjustment

------------------------------------------------------------------------

# 8. Step 8 -- Attribution Check

Evaluate impact of new VA entry point on MoMo Home.

Segment users:

  Segment       Description
  ------------- --------------
  Legacy flow   TTT miniapp
  New flow      MoMo Home UI

Compare:

conversion_rate\
transactions_per_user

------------------------------------------------------------------------

# 9. Step 9 -- Final Decision Criteria

Growth considered valid if:

1.  p‑value \< 0.05
2.  effect size \> 10%
3.  observed across multiple metrics (users, transactions, GMV)

------------------------------------------------------------------------

# 10. Deliverables

Final report should include:

1.  Clean population trend chart
2.  Significance test results
3.  Effect size estimation
4.  Attribution analysis
