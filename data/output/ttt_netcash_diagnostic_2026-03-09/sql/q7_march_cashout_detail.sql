-- Q7: March Cashout Detail 2025 vs 2026 (MTD 9 days each)
SELECT
  EXTRACT(YEAR FROM GRASS_DATE) AS yr,
  ROUND(SUM(COALESCE(cashout_gmv,0)) / 1e9, 0) AS co_thuan_B,
  ROUND(SUM(COALESCE(cashout_napas_gmv,0)) / 1e9, 0) AS co_napas_B,
  ROUND(SUM(COALESCE(cashout_p2p_gmv,0)) / 1e9, 0) AS co_p2p_B,
  ROUND(SUM(COALESCE(cashout_payment_gmv,0)) / 1e9, 0) AS co_payment_B,
  ROUND(SUM(COALESCE(cashout_stock_gmv,0)) / 1e9, 0) AS co_stock_B,
  ROUND(SUM(COALESCE(cashout_mp_gmv,0)) / 1e9, 0) AS co_mp_B,
  ROUND(SUM(COALESCE(cashout_payment_mp_gmv,0)) / 1e9, 0) AS co_pay_mp_B,
  SUM(COALESCE(cashout_trans,0)) AS co_thuan_trans,
  SUM(COALESCE(cashout_napas_trans,0)) AS co_napas_trans,
  SUM(COALESCE(cashout_p2p_trans,0)) AS co_p2p_trans,
  COUNT(DISTINCT CASE WHEN (COALESCE(cashout_gmv,0) + COALESCE(cashout_napas_gmv,0) + COALESCE(cashout_payment_gmv,0) +
    COALESCE(cashout_stock_gmv,0) + COALESCE(cashout_p2p_gmv,0) + COALESCE(cashout_mp_gmv,0) + COALESCE(cashout_payment_mp_gmv,0)) > 0
    THEN REGEXP_EXTRACT(USER_ID, r'\d+') END) AS active_co_users
FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
WHERE (GRASS_DATE BETWEEN '2025-03-01' AND '2025-03-09')
   OR (GRASS_DATE BETWEEN '2026-03-01' AND '2026-03-09')
GROUP BY yr
ORDER BY yr
