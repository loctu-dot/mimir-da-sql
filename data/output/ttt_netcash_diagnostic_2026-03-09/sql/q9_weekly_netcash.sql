-- Q9: Weekly Net Cash 2026 (Tỷ VND)
SELECT
  DATE_TRUNC(GRASS_DATE, WEEK(MONDAY)) AS week_start,
  ROUND(SUM(
    COALESCE(cashin_gmv,0) + COALESCE(cashin_p2p_gmv,0) + COALESCE(cashin_va_gmv,0) +
    COALESCE(cashin_ai_gmv,0) + COALESCE(cashin_stock_gmv,0) + COALESCE(cashin_payout_gmv,0) +
    COALESCE(cashin_mp_gmv,0) + COALESCE(cashin_mp_active_gmv,0)
  ) / 1e9, 0) AS cashin_B,
  ROUND(SUM(
    COALESCE(cashout_gmv,0) + COALESCE(cashout_napas_gmv,0) + COALESCE(cashout_payment_gmv,0) +
    COALESCE(cashout_stock_gmv,0) + COALESCE(cashout_p2p_gmv,0) +
    COALESCE(cashout_mp_gmv,0) + COALESCE(cashout_payment_mp_gmv,0)
  ) / 1e9, 0) AS cashout_B,
  ROUND((SUM(
    COALESCE(cashin_gmv,0) + COALESCE(cashin_p2p_gmv,0) + COALESCE(cashin_va_gmv,0) +
    COALESCE(cashin_ai_gmv,0) + COALESCE(cashin_stock_gmv,0) + COALESCE(cashin_payout_gmv,0) +
    COALESCE(cashin_mp_gmv,0) + COALESCE(cashin_mp_active_gmv,0)
  ) - SUM(
    COALESCE(cashout_gmv,0) + COALESCE(cashout_napas_gmv,0) + COALESCE(cashout_payment_gmv,0) +
    COALESCE(cashout_stock_gmv,0) + COALESCE(cashout_p2p_gmv,0) +
    COALESCE(cashout_mp_gmv,0) + COALESCE(cashout_payment_mp_gmv,0)
  )) / 1e9, 0) AS net_cash_B,
  COUNT(DISTINCT REGEXP_EXTRACT(USER_ID, r'\d+')) AS users
FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
WHERE GRASS_DATE BETWEEN '2025-12-29' AND '2026-03-09'
GROUP BY week_start
ORDER BY week_start
