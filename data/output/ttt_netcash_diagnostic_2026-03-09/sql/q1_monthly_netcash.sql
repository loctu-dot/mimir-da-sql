-- Q1: Monthly Net Cash (Tỷ VND) - Updated through 9/3/2026
SELECT
  FORMAT_DATE('%Y-%m', GRASS_DATE) AS month,
  ROUND(SUM(
    COALESCE(cashin_gmv,0) + COALESCE(cashin_p2p_gmv,0) + COALESCE(cashin_va_gmv,0) +
    COALESCE(cashin_ai_gmv,0) + COALESCE(cashin_stock_gmv,0) + COALESCE(cashin_payout_gmv,0) +
    COALESCE(cashin_mp_gmv,0) + COALESCE(cashin_mp_active_gmv,0)
  ) / 1e9, 0) AS total_cashin_B,
  ROUND(SUM(
    COALESCE(cashout_gmv,0) + COALESCE(cashout_napas_gmv,0) + COALESCE(cashout_payment_gmv,0) +
    COALESCE(cashout_stock_gmv,0) + COALESCE(cashout_p2p_gmv,0) +
    COALESCE(cashout_mp_gmv,0) + COALESCE(cashout_payment_mp_gmv,0)
  ) / 1e9, 0) AS total_cashout_B,
  ROUND((SUM(
    COALESCE(cashin_gmv,0) + COALESCE(cashin_p2p_gmv,0) + COALESCE(cashin_va_gmv,0) +
    COALESCE(cashin_ai_gmv,0) + COALESCE(cashin_stock_gmv,0) + COALESCE(cashin_payout_gmv,0) +
    COALESCE(cashin_mp_gmv,0) + COALESCE(cashin_mp_active_gmv,0)
  ) - SUM(
    COALESCE(cashout_gmv,0) + COALESCE(cashout_napas_gmv,0) + COALESCE(cashout_payment_gmv,0) +
    COALESCE(cashout_stock_gmv,0) + COALESCE(cashout_p2p_gmv,0) +
    COALESCE(cashout_mp_gmv,0) + COALESCE(cashout_payment_mp_gmv,0)
  )) / 1e9, 0) AS net_cash_B,
  COUNT(DISTINCT REGEXP_EXTRACT(USER_ID, r'\d+')) AS unique_users
FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
WHERE GRASS_DATE BETWEEN '2025-01-01' AND '2026-03-09'
GROUP BY month
ORDER BY month
