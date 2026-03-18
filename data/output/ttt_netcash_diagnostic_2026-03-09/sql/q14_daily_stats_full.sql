-- Q14: Daily net cash, CI, CO, CO_P2P — Full 2025 + Q1/2026
-- Purpose: Lấy daily data 430+ ngày cho kiểm định thống kê sample size lớn
-- Expected scan: ~700GB (full table scan mart_ttt_daily_user_record)
-- Expected rows: ~430 (1 row per day)
SELECT
  GRASS_DATE,
  SUM(netcash) / 1e9 AS net_cash_ty,
  SUM(COALESCE(cashin_gmv,0) + COALESCE(cashin_p2p_gmv,0) + COALESCE(cashin_va_gmv,0)
    + COALESCE(cashin_ai_gmv,0) + COALESCE(cashin_stock_gmv,0) + COALESCE(cashin_payout_gmv,0)) / 1e9 AS ci_total_ty,
  SUM(COALESCE(cashout_gmv,0) + COALESCE(cashout_napas_gmv,0) + COALESCE(cashout_payment_gmv,0)
    + COALESCE(cashout_stock_gmv,0) + COALESCE(cashout_p2p_gmv,0) + COALESCE(cashout_mp_gmv,0)
    + COALESCE(cashout_payment_mp_gmv,0)) / 1e9 AS co_total_ty,
  SUM(COALESCE(cashout_p2p_gmv,0)) / 1e9 AS co_p2p_ty
FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
WHERE GRASS_DATE BETWEEN '2025-01-01' AND '2026-03-09'
GROUP BY GRASS_DATE
ORDER BY GRASS_DATE
