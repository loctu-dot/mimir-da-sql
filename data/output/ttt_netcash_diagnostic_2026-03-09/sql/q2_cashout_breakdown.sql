-- Q2: Cashout Breakdown by Channel (Tỷ VND)
SELECT
  FORMAT_DATE('%Y-%m', GRASS_DATE) AS month,
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
  ) / 1e9, 0) AS total_co_B
FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
WHERE GRASS_DATE BETWEEN '2025-01-01' AND '2026-03-09'
GROUP BY month
ORDER BY month
