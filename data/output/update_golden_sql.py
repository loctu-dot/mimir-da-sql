import openpyxl

EXCEL = 'C:/Users/loc.tu/Desktop/project_aaa/mimir-da-sql/data/input/TTT_GOLDEN Benchmark.xlsx'

wb = openpyxl.load_workbook(EXCEL)
ws = wb.active

SKIP = {'TTT013', 'TTT018', 'TTT020', 'TTT022', 'TTT024', 'TTT027', 'TTT051'}

REWRITES = {}

REWRITES['TTT005'] = """-- AUM (snapshot) + MAU (count) for current vs last month
WITH aum AS (
  SELECT DATE_TRUNC(GRASS_DATE, MONTH) AS month, SUM(BALANCE) AS aum
  FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
  WHERE GRASS_DATE IN (
    CURRENT_DATE('+7')-1,
    LAST_DAY(DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 1 MONTH))
  )
  GROUP BY 1
),
mau AS (
  SELECT DATE_TRUNC(GRASS_DATE, MONTH) AS month,
    COUNT(DISTINCT CASE WHEN MAU_TYPE != '0.Churn' THEN CAST(REGEXP_EXTRACT(USER_ID, r'\\d+') AS STRING) END) AS mau
  FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
  WHERE GRASS_DATE BETWEEN DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 1 MONTH) AND CURRENT_DATE('+7')-1
  GROUP BY 1
)
SELECT a.month, a.aum, m.mau FROM aum a JOIN mau m ON a.month = m.month ORDER BY a.month"""

REWRITES['TTT008'] = """SELECT AGE_GROUP,
  COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\\d+') AS STRING)) AS user_count,
  SUM(BALANCE) AS total_balance,
  AVG(BALANCE) AS avg_balance,
  SUM(COALESCE(cashin_gmv,0)+COALESCE(cashin_p2p_gmv,0)+COALESCE(cashin_va_gmv,0)+COALESCE(cashin_ai_gmv,0)+COALESCE(cashin_stock_gmv,0)+COALESCE(cashin_payout_gmv,0)+COALESCE(cashin_mp_gmv,0)) AS total_cashin
FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
WHERE GRASS_DATE BETWEEN DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH) AND CURRENT_DATE('+7')-1
AND MFU_TYPE != '0.Churn'
GROUP BY AGE_GROUP
ORDER BY total_balance DESC"""

REWRITES['TTT011'] = """-- TTT027 pattern: Same Period + Month by Month for fair MTD comparison
WITH unique_by_day AS (
  SELECT DATE_TRUNC(GRASS_DATE, MONTH) AS month, GRASS_DATE AS date,
    CAST(REGEXP_EXTRACT(USER_ID, r'\\d+') AS STRING) AS uid
  FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
  WHERE GRASS_DATE BETWEEN DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 1 MONTH) AND CURRENT_DATE('+7')-1
  AND MAU_TYPE = '1.New'
  QUALIFY ROW_NUMBER() OVER(PARTITION BY uid, month ORDER BY GRASS_DATE) = 1
),
calculation AS (
  SELECT month, date, COUNT(DISTINCT uid) AS new_users
  FROM unique_by_day GROUP BY ALL
),
final AS (
  SELECT 'Same Period' AS time_interval, t1.month,
    SUM(t1.new_users) AS current_month, SUM(t2.new_users) AS last_month
  FROM calculation t1
  JOIN calculation t2
    ON t1.month = DATE_ADD(t2.month, INTERVAL 1 MONTH)
    AND EXTRACT(DAY FROM t1.date) = EXTRACT(DAY FROM t2.date)
  GROUP BY month
  UNION ALL
  SELECT 'Month by Month', t1.month, t1.new_users, t2.new_users
  FROM (SELECT month, SUM(new_users) AS new_users FROM calculation WHERE month = DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH) GROUP BY month) t1
  JOIN (SELECT month, SUM(new_users) AS new_users FROM calculation WHERE month = DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 1 MONTH) GROUP BY month) t2
    ON t1.month = DATE_ADD(t2.month, INTERVAL 1 MONTH)
)
SELECT * FROM final"""

REWRITES['TTT014'] = """WITH monthly_churn AS (
  SELECT DATE_TRUNC(GRASS_DATE, MONTH) AS month,
    COUNT(DISTINCT CASE WHEN MAU_TYPE = '0.Churn' THEN CAST(REGEXP_EXTRACT(USER_ID, r'\\d+') AS STRING) END) AS churned,
    COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\\d+') AS STRING)) AS total
  FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
  WHERE GRASS_DATE BETWEEN DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 2 MONTH) AND CURRENT_DATE('+7')-1
  GROUP BY 1
)
SELECT month, churned, total, ROUND(churned * 100.0 / NULLIF(total, 0), 2) AS churn_rate_pct
FROM monthly_churn ORDER BY month"""

REWRITES['TTT015'] = """WITH aum AS (
  SELECT EXTRACT(YEAR FROM GRASS_DATE) AS yr, SUM(BALANCE) AS total_aum
  FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
  WHERE GRASS_DATE IN (
    CURRENT_DATE('+7')-1,
    DATE_SUB(CURRENT_DATE('+7')-1, INTERVAL 12 MONTH)
  )
  GROUP BY 1
)
SELECT curr.total_aum AS aum_current_year, prev.total_aum AS aum_same_period_last_year,
  ROUND((curr.total_aum - prev.total_aum) / NULLIF(prev.total_aum, 0) * 100, 2) AS yoy_growth_pct
FROM aum curr JOIN aum prev ON curr.yr = prev.yr + 1"""

REWRITES['TTT016'] = """WITH last_month_churn AS (
  SELECT DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\\d+') AS STRING) AS uid
  FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
  WHERE GRASS_DATE BETWEEN DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 1 MONTH)
    AND LAST_DAY(DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 1 MONTH))
  AND MAU_TYPE = '0.Churn'
),
prev_month_funded AS (
  SELECT DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\\d+') AS STRING) AS uid
  FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
  WHERE GRASS_DATE BETWEEN DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 2 MONTH)
    AND LAST_DAY(DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 2 MONTH))
  AND MFU_TYPE != '0.Churn'
)
SELECT CASE WHEN d.uid IS NOT NULL THEN 'Previously Funded' ELSE 'Never Funded' END AS segment,
  COUNT(*) AS user_count
FROM last_month_churn j LEFT JOIN prev_month_funded d ON j.uid = d.uid
GROUP BY 1"""

REWRITES['TTT030'] = """-- TTT027 pattern: Same Period + Month by Month for NAPAS cashout
WITH daily_napas AS (
  SELECT DATE_TRUNC(GRASS_DATE, MONTH) AS month, GRASS_DATE AS date,
    COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\\d+') AS STRING)) AS napas_users,
    SUM(COALESCE(CASHOUT_NAPAS_GMV, 0)) AS napas_gmv,
    SUM(COALESCE(CASHOUT_NAPAS_TRANS, 0)) AS napas_trans
  FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
  WHERE GRASS_DATE BETWEEN DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 1 MONTH) AND CURRENT_DATE('+7')-1
  AND PLUS_TYPE NOT IN ('0.Churn', 'None') AND PLUS_TYPE IS NOT NULL
  AND CASHOUT_NAPAS_TRANS > 0
  GROUP BY ALL
),
final AS (
  SELECT 'Same Period' AS time_interval, t1.month,
    SUM(t1.napas_users) AS current_users, SUM(t2.napas_users) AS last_users,
    SUM(t1.napas_gmv) AS current_gmv, SUM(t2.napas_gmv) AS last_gmv
  FROM daily_napas t1
  JOIN daily_napas t2
    ON t1.month = DATE_ADD(t2.month, INTERVAL 1 MONTH)
    AND EXTRACT(DAY FROM t1.date) = EXTRACT(DAY FROM t2.date)
  GROUP BY month
  UNION ALL
  SELECT 'Month by Month', t1.month, t1.u, t2.u, t1.g, t2.g
  FROM (SELECT month, SUM(napas_users) AS u, SUM(napas_gmv) AS g FROM daily_napas WHERE month = DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH) GROUP BY month) t1
  JOIN (SELECT month, SUM(napas_users) AS u, SUM(napas_gmv) AS g FROM daily_napas WHERE month = DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 1 MONTH) GROUP BY month) t2
    ON t1.month = DATE_ADD(t2.month, INTERVAL 1 MONTH)
)
SELECT * FROM final"""

REWRITES['TTT038'] = """WITH reactive_last_month AS (
  SELECT DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\\d+') AS STRING) AS uid
  FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
  WHERE GRASS_DATE BETWEEN DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 1 MONTH)
    AND LAST_DAY(DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 1 MONTH))
  AND MAU_TYPE = '3.Reactive'
),
last_month_metrics AS (
  SELECT CAST(REGEXP_EXTRACT(USER_ID, r'\\d+') AS STRING) AS uid,
    SUM(COALESCE(cashin_gmv,0)+COALESCE(cashin_p2p_gmv,0)+COALESCE(cashin_va_gmv,0)+COALESCE(cashin_ai_gmv,0)+COALESCE(cashin_stock_gmv,0)+COALESCE(cashin_payout_gmv,0)+COALESCE(cashin_mp_gmv,0)) AS total_cashin
  FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
  WHERE GRASS_DATE BETWEEN DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 1 MONTH)
    AND LAST_DAY(DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 1 MONTH))
  AND CAST(REGEXP_EXTRACT(USER_ID, r'\\d+') AS STRING) IN (SELECT uid FROM reactive_last_month)
  GROUP BY 1
),
current_month_active AS (
  SELECT DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\\d+') AS STRING) AS uid
  FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record`
  WHERE GRASS_DATE BETWEEN DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH) AND CURRENT_DATE('+7')-1
  AND MAU_TYPE != '0.Churn'
)
SELECT COUNT(DISTINCT f.uid) AS reactive_users,
  SUM(f.total_cashin) AS total_reactive_cashin,
  AVG(f.total_cashin) AS avg_cashin_per_user,
  COUNT(DISTINCT m.uid) AS retained_this_month,
  ROUND(COUNT(DISTINCT m.uid) * 100.0 / NULLIF(COUNT(DISTINCT f.uid), 0), 2) AS retention_pct
FROM last_month_metrics f LEFT JOIN current_month_active m ON f.uid = m.uid"""


def make_dynamic(sql):
    has_feb = "'2026-02-" in sql
    if has_feb:
        sql = sql.replace("'2026-02-28'", "CURRENT_DATE('+7')-1")
        sql = sql.replace("'2026-02-01'", "DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH)")
        sql = sql.replace("'2026-01-31'", "LAST_DAY(DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 1 MONTH))")
        sql = sql.replace("'2026-01-01'", "DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 1 MONTH)")
    else:
        sql = sql.replace("'2026-01-31'", "CURRENT_DATE('+7')-1")
        sql = sql.replace("'2026-01-01'", "DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH)")
    sql = sql.replace("'2025-12-31'", "LAST_DAY(DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 2 MONTH))")
    sql = sql.replace("'2025-12-01'", "DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 2 MONTH)")
    sql = sql.replace("'2025-11-01'", "DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 4 MONTH)")
    sql = sql.replace("'2025-10-01'", "DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 5 MONTH)")
    sql = sql.replace("'2025-09-01'", "DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 6 MONTH)")
    sql = sql.replace("'2025-09-30'", "LAST_DAY(DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 6 MONTH))")
    sql = sql.replace("'2025-07-01'", "DATE_SUB(DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH), INTERVAL 8 MONTH)")
    sql = sql.replace("'2025-01-31'", "DATE_SUB(CURRENT_DATE('+7')-1, INTERVAL 12 MONTH)")
    sql = sql.replace("'2026-03-01'", "DATE_TRUNC(CURRENT_DATE('+7')-1, MONTH)")
    sql = sql.replace("'2026-03-08'", "CURRENT_DATE('+7')-1")
    return sql


updated = 0
skipped = []
rewritten = []
date_fixed = []

for r in range(2, ws.max_row + 1):
    ttt_id = ws.cell(r, 1).value
    if ttt_id in SKIP:
        skipped.append(ttt_id)
        continue
    if ttt_id in REWRITES:
        ws.cell(r, 8).value = REWRITES[ttt_id]
        rewritten.append(ttt_id)
        updated += 1
        continue
    old_sql = ws.cell(r, 8).value or ''
    new_sql = make_dynamic(old_sql)
    if new_sql != old_sql:
        ws.cell(r, 8).value = new_sql
        date_fixed.append(ttt_id)
        updated += 1

wb.save(EXCEL)

print(f"Total updated: {updated}")
print(f"Skipped ({len(skipped)}): {', '.join(skipped)}")
print(f"Full rewrites ({len(rewritten)}): {', '.join(rewritten)}")
print(f"Date fixes ({len(date_fixed)}): {', '.join(date_fixed)}")
