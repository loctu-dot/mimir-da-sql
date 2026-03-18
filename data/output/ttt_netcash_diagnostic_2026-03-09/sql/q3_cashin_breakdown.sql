-- Q3: Cashin Breakdown by Channel (Tỷ VND)
SELECT
  FORMAT_DATE('%Y-%m', GRASS_DATE) AS month,
  ROUND(SUM(COALESCE(cashin_gmv,0)) / 1e9, 0) AS ci_thuan_B,
  ROUND(SUM(COALESCE(cashin_p2p_gmv,0)) / 1e9, 0) AS ci_p2p_B,
  ROUND(SUM(COALESCE(cashin_va_gmv,0)) / 1e9, 0) AS ci_va_B,
  ROUND(SUM(COALESCE(cashin_ai_gmv,0)) / 1e9, 0) AS ci_ai_B,
  ROUND(SUM(COALESCE(cashin_stock_gmv,0)) / 1e9, 0) AS ci_stock_B,
  ROUND(SUM(COALESCE(cashin_payout_gmv,0)) / 1e9, 0) AS ci_payout_B,
  ROUND(SUM(COALESCE(cashin_mp_gmv,0)) / 1e9, 0) AS ci_mp_B,
  ROUND(SUM(COALESCE(cashin_mp_active_gmv,0)) / 1e9, 0) AS ci_mp_active_B,
  ROUND(SUM(
    COALESCE(cashin_gmv,0) + COALESCE(cashin_p2p_gmv,0) + COALESCE(cashin_va_gmv,0) +
    COALESCE(cashin_ai_gmv,0) + COALESCE(cashin_stock_gmv,0) + COALESCE(cashin_payout_gmv,0) +
    COALESCE(cashin_mp_gmv,0) + COALESCE(cashin_mp_active_gmv,0)
  ) / 1e9, 0) AS total_ci_B
FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
WHERE GRASS_DATE BETWEEN '2025-01-01' AND '2026-03-09'
GROUP BY month
ORDER BY month
