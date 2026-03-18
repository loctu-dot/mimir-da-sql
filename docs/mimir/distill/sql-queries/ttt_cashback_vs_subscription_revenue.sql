-- ============================================================
-- TỔNG CHI PHÍ TÚI+ vs DOANH THU BÁN TÚI+ (6 tháng tới MTD)
-- ============================================================
-- Chi phí Túi+ gồm 3 thành phần:
--   1. Cashback 0.1%     : TOTAL_CASHBACK_GMV (đã là VND)
--   2. Xu sinh lời        : COIN_INTEREST (xu) → VND = COIN_INTEREST / 2
--   3. Xu SOF (thưởng TT) : COIN_SOF (xu) → VND = COIN_SOF / 2
--   Menh giá: 2 xu MoMo = 1 VND

-- Doanh thu Túi+:
--   Subscription fee qua PLUS_SEGMENT (Buy suffix)
--   Pre-2026: TTT+ 9k flat = 9,000 VND
--   Post-2026: Silver=9K, Gold=19K, Platinum=49K
--   Upgrade trong tháng chỉ trả chênh lệch

-- Date range: 6 tháng qua tới MTD (hôm qua, data lag 1 ngày)
-- ============================================================

WITH
-- ===== PART A: SUBSCRIPTION REVENUE =====

-- A1: Pre-2026 (Sep–Dec 2025): chưa có tier, chỉ có TTT+ 9k flat
pre_2026_rev AS (
  SELECT
    DATE_TRUNC(GRASS_DATE, MONTH) AS month,
    CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) AS uid,
    9000 AS subscription_revenue
  FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
  WHERE GRASS_DATE BETWEEN '2025-09-01' AND '2025-12-31'
    AND PLUS_SEGMENT = 'TTT+ 9k'
  GROUP BY 1, 2
),

-- A2: Post-2026 (Jan 2026 → MTD): detect daily tier upgrades
--     Include 2025-12-31 để LAG có context cho ngày 01/01/2026
post_2026_daily AS (
  SELECT
    GRASS_DATE,
    DATE_TRUNC(GRASS_DATE, MONTH) AS month,
    CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) AS uid,
    COALESCE(TIER, 'None') AS tier,
    COALESCE(PLUS_SEGMENT, '') AS plus_segment,
    LAG(COALESCE(TIER, 'None')) OVER (
      PARTITION BY CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)
      ORDER BY GRASS_DATE
    ) AS prev_tier
  FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
  WHERE GRASS_DATE BETWEEN '2025-12-31'
    AND DATE_SUB(CURRENT_DATE('+7'), INTERVAL 1 DAY)
),

-- Tier price map: None=0, Silver=9K, Gold=19K, Platinum=49K
-- Revenue per upgrade = new_price − old_price
post_2026_rev AS (
  SELECT
    month,
    uid,
    SUM(
      ( CASE tier
          WHEN 'Platinum' THEN 49000
          WHEN 'Gold'     THEN 19000
          WHEN 'Silver'   THEN 9000
          ELSE 0
        END )
      -
      ( CASE prev_tier
          WHEN 'Platinum' THEN 49000
          WHEN 'Gold'     THEN 19000
          WHEN 'Silver'   THEN 9000
          ELSE 0
        END )
    ) AS subscription_revenue
  FROM post_2026_daily
  WHERE GRASS_DATE >= '2026-01-01'
    AND plus_segment LIKE '%Buy%'
    AND tier != COALESCE(prev_tier, 'None')
    AND (
      CASE tier
        WHEN 'Platinum' THEN 49000 WHEN 'Gold' THEN 19000
        WHEN 'Silver' THEN 9000 ELSE 0
      END
      >
      CASE prev_tier
        WHEN 'Platinum' THEN 49000 WHEN 'Gold' THEN 19000
        WHEN 'Silver' THEN 9000 ELSE 0
      END
    )
  GROUP BY month, uid
),

all_revenue AS (
  SELECT * FROM pre_2026_rev
  UNION ALL
  SELECT * FROM post_2026_rev
),

-- ===== PART B: TỔNG CHI PHÍ TÚI+ (3 thành phần) =====
monthly_user_metrics AS (
  SELECT
    DATE_TRUNC(GRASS_DATE, MONTH) AS month,
    CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) AS uid,
    -- 1. Cashback 0.1% (VND)
    SUM(COALESCE(TOTAL_CASHBACK_GMV, 0))                AS cashback_cost,
    -- 2. Xu sinh lời → VND (2 xu = 1 VND)
    SUM(COALESCE(COIN_INTEREST, 0)) / 2                  AS coin_int_cost,
    -- 3. Xu SOF thưởng thanh toán → VND
    SUM(COALESCE(COIN_SOF, 0)) / 2                       AS coin_sof_cost
  FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
  WHERE GRASS_DATE BETWEEN '2025-09-01'
    AND DATE_SUB(CURRENT_DATE('+7'), INTERVAL 1 DAY)
    AND PLUS_TYPE NOT IN ('0.Churn', 'None')
    AND PLUS_TYPE IS NOT NULL
  GROUP BY 1, 2
)

-- ===== FINAL: SO SÁNH MONTHLY =====
SELECT
  m.month,

  -- Users breakdown
  COUNT(DISTINCT m.uid)                                              AS total_plus_users,
  COUNT(DISTINCT r.uid)                                              AS paid_subscription_users,

  -- ===== CHI PHÍ (3 thành phần) =====
  -- 1. Cashback
  ROUND(SUM(m.cashback_cost), 0)                                    AS total_cashback_cost,
  -- 2. Xu sinh lời (VND)
  ROUND(SUM(m.coin_int_cost), 0)                                    AS total_coin_int_cost,
  -- 3. Xu SOF (VND)
  ROUND(SUM(m.coin_sof_cost), 0)                                    AS total_coin_sof_cost,
  -- Tổng chi phí Túi+
  ROUND(SUM(m.cashback_cost)
      + SUM(m.coin_int_cost)
      + SUM(m.coin_sof_cost), 0)                                    AS total_cost,
  -- Avg tổng chi phí / user Túi+
  ROUND((SUM(m.cashback_cost)
       + SUM(m.coin_int_cost)
       + SUM(m.coin_sof_cost))
    / NULLIF(COUNT(DISTINCT m.uid), 0), 0)                          AS avg_total_cost_per_user,

  -- ===== DOANH THU (subscription, đã trừ upgrade discount) =====
  ROUND(COALESCE(SUM(r.subscription_revenue), 0), 0)                AS total_subscription_revenue,
  ROUND(COALESCE(SUM(r.subscription_revenue), 0)
    / NULLIF(COUNT(DISTINCT r.uid), 0), 0)                           AS avg_revenue_per_paid_user,
  ROUND(COALESCE(SUM(r.subscription_revenue), 0)
    / NULLIF(COUNT(DISTINCT m.uid), 0), 0)                           AS avg_rev_per_plus_user,

  -- ===== NET & RATIO =====
  ROUND(
    (COALESCE(SUM(r.subscription_revenue), 0)
     - SUM(m.cashback_cost)
     - SUM(m.coin_int_cost)
     - SUM(m.coin_sof_cost))
    / NULLIF(COUNT(DISTINCT m.uid), 0), 0
  )                                                                  AS net_per_plus_user,

  ROUND(COALESCE(SUM(r.subscription_revenue), 0)
    / NULLIF(SUM(m.cashback_cost)
           + SUM(m.coin_int_cost)
           + SUM(m.coin_sof_cost), 0), 4)                           AS revenue_cost_ratio

FROM monthly_user_metrics m
LEFT JOIN all_revenue r ON r.month = m.month AND r.uid = m.uid
GROUP BY m.month
ORDER BY m.month
