-- Q4: Daily March 2025 vs 2026 comparison (Tỷ VND)
WITH daily AS (
  SELECT
    EXTRACT(DAY FROM GRASS_DATE) AS day_num,
    EXTRACT(YEAR FROM GRASS_DATE) AS yr,
    ROUND(SUM(
      COALESCE(cashin_gmv,0) + COALESCE(cashin_p2p_gmv,0) + COALESCE(cashin_va_gmv,0) +
      COALESCE(cashin_ai_gmv,0) + COALESCE(cashin_stock_gmv,0) + COALESCE(cashin_payout_gmv,0) +
      COALESCE(cashin_mp_gmv,0) + COALESCE(cashin_mp_active_gmv,0)
    ) / 1e9, 0) AS cashin_B,
    ROUND(SUM(
      COALESCE(cashout_gmv,0) + COALESCE(cashout_napas_gmv,0) + COALESCE(cashout_payment_gmv,0) +
      COALESCE(cashout_stock_gmv,0) + COALESCE(cashout_p2p_gmv,0) +
      COALESCE(cashout_mp_gmv,0) + COALESCE(cashout_payment_mp_gmv,0)
    ) / 1e9, 0) AS cashout_B
  FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
  WHERE (GRASS_DATE BETWEEN '2025-03-01' AND '2025-03-09')
     OR (GRASS_DATE BETWEEN '2026-03-01' AND '2026-03-09')
  GROUP BY day_num, yr
)
SELECT
  day_num,
  MAX(CASE WHEN yr=2025 THEN cashin_B END) AS ci_2025,
  MAX(CASE WHEN yr=2025 THEN cashout_B END) AS co_2025,
  MAX(CASE WHEN yr=2025 THEN cashin_B - cashout_B END) AS net_2025,
  MAX(CASE WHEN yr=2026 THEN cashin_B END) AS ci_2026,
  MAX(CASE WHEN yr=2026 THEN cashout_B END) AS co_2026,
  MAX(CASE WHEN yr=2026 THEN cashin_B - cashout_B END) AS net_2026
FROM daily
GROUP BY day_num
ORDER BY day_num
