-- Q16: AUM by TIER for TTT+ users — monthly snapshots
-- Purpose: Xem AUM per-user Platinum có tăng trước rồi giảm, hay luôn giảm
-- Expected scan: ~700GB
-- Expected rows: ~45 (15 months × 3 tiers)

WITH month_ends AS (
  SELECT DATE '2025-01-31' AS snap_date UNION ALL
  SELECT DATE '2025-02-28' UNION ALL
  SELECT DATE '2025-03-31' UNION ALL
  SELECT DATE '2025-04-30' UNION ALL
  SELECT DATE '2025-05-31' UNION ALL
  SELECT DATE '2025-06-30' UNION ALL
  SELECT DATE '2025-07-31' UNION ALL
  SELECT DATE '2025-08-31' UNION ALL
  SELECT DATE '2025-09-30' UNION ALL
  SELECT DATE '2025-10-31' UNION ALL
  SELECT DATE '2025-11-30' UNION ALL
  SELECT DATE '2025-12-31' UNION ALL
  SELECT DATE '2026-01-31' UNION ALL
  SELECT DATE '2026-02-28' UNION ALL
  SELECT DATE '2026-03-09'
)
SELECT
  m.snap_date,
  t.TIER,
  SUM(t.balance) / 1e9 AS aum_ty,
  COUNT(DISTINCT t.USER_ID) AS user_count,
  SUM(t.balance) / NULLIF(COUNT(DISTINCT t.USER_ID), 0) / 1e6 AS aum_per_user_trieu
FROM month_ends m
JOIN `momovn-prod.BU_FI.mart_ttt_daily_user_record` t
  ON t.GRASS_DATE = m.snap_date
WHERE t.TYPE = 'TTT+'
  AND t.balance > 0
GROUP BY m.snap_date, t.TIER
ORDER BY m.snap_date, t.TIER
