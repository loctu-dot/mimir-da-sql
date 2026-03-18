-- Q13: TTT+ PLUS_SEGMENT breakdown for March 2025 vs 2026
-- Shows which TTT+ segments drive the net cash drain
SELECT
  EXTRACT(YEAR FROM GRASS_DATE) AS yr,
  PLUS_SEGMENT,
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
  ROUND(SUM(COALESCE(netcash,0)) / 1e9, 0) AS netcash_B,
  COUNT(DISTINCT REGEXP_EXTRACT(USER_ID, r'\d+')) AS unique_users,
  ROUND(SUM(COALESCE(cashout_p2p_gmv,0)) / 1e9, 0) AS co_p2p_B,
  ROUND(SUM(COALESCE(cashout_payment_gmv,0)) / 1e9, 0) AS co_payment_B,
  ROUND(SUM(COALESCE(cashout_napas_gmv,0)) / 1e9, 0) AS co_napas_B
FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
WHERE TYPE = 'TTT+'
  AND ((GRASS_DATE BETWEEN '2025-03-01' AND '2025-03-09')
    OR (GRASS_DATE BETWEEN '2026-03-01' AND '2026-03-09'))
GROUP BY yr, PLUS_SEGMENT
ORDER BY yr, netcash_B
