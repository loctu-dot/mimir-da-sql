-- Q7b: March 2026 Cashout by TYPE (MTD 9d)
SELECT
  TYPE,
  ROUND(SUM(COALESCE(cashout_gmv,0)) / 1e9, 0) AS co_thuan_B,
  ROUND(SUM(COALESCE(cashout_napas_gmv,0)) / 1e9, 0) AS co_napas_B,
  ROUND(SUM(COALESCE(cashout_p2p_gmv,0)) / 1e9, 0) AS co_p2p_B,
  ROUND(SUM(COALESCE(cashout_payment_gmv,0)) / 1e9, 0) AS co_payment_B,
  ROUND(SUM(COALESCE(cashout_stock_gmv,0)) / 1e9, 0) AS co_stock_B,
  ROUND(SUM(COALESCE(cashout_mp_gmv,0)) / 1e9, 0) AS co_mp_B,
  ROUND(SUM(COALESCE(cashout_payment_mp_gmv,0)) / 1e9, 0) AS co_pay_mp_B,
  ROUND(SUM(
    COALESCE(cashout_gmv,0) + COALESCE(cashout_napas_gmv,0) + COALESCE(cashout_payment_gmv,0) +
    COALESCE(cashout_stock_gmv,0) + COALESCE(cashout_p2p_gmv,0) +
    COALESCE(cashout_mp_gmv,0) + COALESCE(cashout_payment_mp_gmv,0)
  ) / 1e9, 0) AS total_co_B,
  COUNT(DISTINCT REGEXP_EXTRACT(USER_ID, r'\d+')) AS unique_users
FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
WHERE GRASS_DATE BETWEEN '2026-03-01' AND '2026-03-09'
GROUP BY TYPE
ORDER BY TYPE
