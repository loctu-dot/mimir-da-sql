-- Q11: Cashin/Cashout Per User
SELECT
  FORMAT_DATE('%Y-%m', GRASS_DATE) AS month,
  ROUND(SUM(
    COALESCE(cashout_gmv,0) + COALESCE(cashout_napas_gmv,0) + COALESCE(cashout_payment_gmv,0) +
    COALESCE(cashout_stock_gmv,0) + COALESCE(cashout_p2p_gmv,0) +
    COALESCE(cashout_mp_gmv,0) + COALESCE(cashout_payment_mp_gmv,0)
  ) / 1e9, 0) AS active_co_gmv_B,
  COUNT(DISTINCT CASE WHEN (COALESCE(cashout_gmv,0) + COALESCE(cashout_napas_gmv,0) + COALESCE(cashout_payment_gmv,0) +
    COALESCE(cashout_stock_gmv,0) + COALESCE(cashout_p2p_gmv,0) + COALESCE(cashout_mp_gmv,0) + COALESCE(cashout_payment_mp_gmv,0)) > 0
    THEN REGEXP_EXTRACT(USER_ID, r'\d+') END) AS active_co_users,
  ROUND(SUM(
    COALESCE(cashin_gmv,0) + COALESCE(cashin_p2p_gmv,0) + COALESCE(cashin_va_gmv,0) +
    COALESCE(cashin_ai_gmv,0) + COALESCE(cashin_stock_gmv,0) + COALESCE(cashin_payout_gmv,0) +
    COALESCE(cashin_mp_gmv,0) + COALESCE(cashin_mp_active_gmv,0)
  ) / 1e9, 0) AS total_ci_gmv_B,
  COUNT(DISTINCT CASE WHEN (COALESCE(cashin_gmv,0) + COALESCE(cashin_p2p_gmv,0) + COALESCE(cashin_va_gmv,0) +
    COALESCE(cashin_ai_gmv,0) + COALESCE(cashin_stock_gmv,0) + COALESCE(cashin_payout_gmv,0) +
    COALESCE(cashin_mp_gmv,0) + COALESCE(cashin_mp_active_gmv,0)) > 0
    THEN REGEXP_EXTRACT(USER_ID, r'\d+') END) AS ci_users
FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
WHERE GRASS_DATE BETWEEN '2025-01-01' AND '2026-03-09'
  AND FORMAT_DATE('%Y-%m', GRASS_DATE) IN ('2025-01','2025-02','2025-03','2025-06','2025-09','2025-12','2026-01','2026-02','2026-03')
GROUP BY month
ORDER BY month
