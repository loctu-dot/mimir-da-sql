# TTT Benchmark Questions — 50 Test Cases

> **Domain:** Túi Thần Tài (TTT)
> **Table chính:** `momovn-prod.BU_FI.mart_ttt_daily_user_record` (mart), `momovn-prod.BU_FI.fact_ttt_event_tracking` (event)
> **Created:** 2026-03-10
> **Purpose:** Benchmark Mimir AI accuracy — câu hỏi viết đúng giọng non-tech stakeholder

---

## Q001

| Field | Value |
|-------|-------|
| **ID** | Q001 |
| **Question (NL)** | AUM tháng 1 bao nhiêu? |
| **Category** | Aggregation |
| **Difficulty** | Simple |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | BALANCE, GRASS_DATE |
| **Business Rules / Notes** | AUM = SUM(BALANCE) tại ngày cuối tháng (snapshot), KHÔNG phải SUM across all days. Nếu SUM cả tháng → inflate ~30x. Không filter MAU/MFU vì churn accounts vẫn có balance. Câu hỏi không nói rõ năm nào → LLM phải infer 2026. Không nói rõ breakdown Individual vs Money Pool → LLM có thể miss hoặc tự ý breakdown. |
| **Gold SQL** | ```sql SELECT SUM(BALANCE) AS total_aum FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE = '2026-01-31' ``` |
| **Gold Result (summary)** | 1 row, total_aum ~11.57T VND |
| **Expected Row Count** | 1 |

---

## Q002

| Field | Value |
|-------|-------|
| **ID** | Q002 |
| **Question (NL)** | Có bao nhiêu người đang dùng TTT vậy? |
| **Category** | Ambiguous |
| **Difficulty** | Ambiguous |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | USER_ID, MAU_TYPE, GRASS_DATE |
| **Business Rules / Notes** | "Đang dùng" = MAU hay MFU? Không nói tháng nào. Agent tốt nên hỏi lại: "Ý anh/chị là người mở app (MAU ~3.5M) hay người thực sự có tiền (MFU ~1.7M)?". USER_ID cần REGEXP_EXTRACT vì mp_ prefix gây double-count. Nếu agent tự đoán mà không clarify → penalty. |
| **Gold SQL** | ```sql -- Agent nên hỏi lại. Nếu buộc phải trả lời, MAU là default hợp lý: SELECT COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS total_mau FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' AND MAU_TYPE != '0.Churn' ``` |
| **Gold Result (summary)** | 1 row, ~3.4-3.5M (nếu MAU) hoặc ~1.67M (nếu MFU) |
| **Expected Row Count** | 1 |

---

## Q003

| Field | Value |
|-------|-------|
| **ID** | Q003 |
| **Question (NL)** | Tháng rồi người ta gửi vô TTT tổng bao nhiêu tiền? |
| **Category** | Aggregation |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | cashin_gmv, cashin_p2p_gmv, cashin_va_gmv, cashin_ai_gmv, cashin_stock_gmv, cashin_payout_gmv, cashin_mp_gmv, GRASS_DATE |
| **Business Rules / Notes** | "Tháng rồi" = tháng trước (agent phải infer). Total cashin = SUM tất cả 7 sub-channels, không chỉ cashin_gmv (~50% total). COALESCE(col, 0) vì NULL. "Gửi vô" = cashin, không phải balance. LLM yếu thường chỉ dùng cashin_gmv. |
| **Gold SQL** | ```sql SELECT SUM( COALESCE(cashin_gmv, 0) + COALESCE(cashin_p2p_gmv, 0) + COALESCE(cashin_va_gmv, 0) + COALESCE(cashin_ai_gmv, 0) + COALESCE(cashin_stock_gmv, 0) + COALESCE(cashin_payout_gmv, 0) + COALESCE(cashin_mp_gmv, 0) ) AS total_cashin FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' ``` |
| **Gold Result (summary)** | 1 row, total cashin cả tháng |
| **Expected Row Count** | 1 |

---

## Q004

| Field | Value |
|-------|-------|
| **ID** | Q004 |
| **Question (NL)** | MoMo đang trả lãi cho TTT mỗi tháng bao nhiêu vậy? Có đáng lo không? |
| **Category** | Aggregation |
| **Difficulty** | Simple |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | INTEREST, GRASS_DATE |
| **Business Rules / Notes** | Column tên `INTEREST` (KHÔNG phải `interest_gmv` — column name sai phổ biến nhất). Interest = chi phí MoMo trả cho user/ngày, SUM across tháng. "Có đáng lo không" = phần business interpretation, agent không cần SQL cho phần này. LLM có thể dùng sai column name → query fail. |
| **Gold SQL** | ```sql SELECT SUM(INTEREST) AS total_interest_paid FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' ``` |
| **Gold Result (summary)** | 1 row, ~37-38B VND/month |
| **Expected Row Count** | 1 |

---

## Q005

| Field | Value |
|-------|-------|
| **ID** | Q005 |
| **Question (NL)** | Tháng 1 so với tháng 2 thì TTT đang lên hay xuống? |
| **Category** | Multi-step |
| **Difficulty** | Ambiguous |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | BALANCE, USER_ID, MAU_TYPE, INTEREST, cashin sub-channels, GRASS_DATE |
| **Business Rules / Notes** | Câu hỏi cực kỳ vague — "lên hay xuống" theo metric nào? AUM? MAU? Cashin? Agent tốt nên hỏi lại hoặc decompose thành multiple metrics. Mỗi metric có date logic khác nhau (AUM = snapshot, MAU = full range, cashin = SUM range). Nếu agent chỉ trả 1 metric → incomplete. |
| **Gold SQL** | ```sql -- Cần multiple queries. Minimum viable: AUM + MAU for 2 months WITH jan_stats AS ( SELECT SUM(CASE WHEN GRASS_DATE = '2026-01-31' THEN BALANCE ELSE 0 END) AS aum, COUNT(DISTINCT CASE WHEN MAU_TYPE != '0.Churn' THEN CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) END) AS mau FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-01-01' AND '2026-01-31' ), feb_stats AS ( SELECT SUM(CASE WHEN GRASS_DATE = '2026-02-28' THEN BALANCE ELSE 0 END) AS aum, COUNT(DISTINCT CASE WHEN MAU_TYPE != '0.Churn' THEN CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) END) AS mau FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' ) SELECT 'Jan' AS month, aum, mau FROM jan_stats UNION ALL SELECT 'Feb', aum, mau FROM feb_stats ``` |
| **Gold Result (summary)** | 2 rows: Jan vs Feb cho AUM + MAU |
| **Expected Row Count** | 2 |

---

## Q006

| Field | Value |
|-------|-------|
| **ID** | Q006 |
| **Question (NL)** | Vùng nào đang dùng TTT nhiều nhất? Top 5 cho t |
| **Category** | Ranking + Filter |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | REGION, USER_ID, MAU_TYPE, GRASS_DATE |
| **Business Rules / Notes** | "Dùng nhiều nhất" = MAU count. Cần filter MAU_TYPE != '0.Churn'. REGEXP_EXTRACT cho USER_ID dedup. REGION có thể NULL → COALESCE. LIMIT 5. Không nói rõ tháng → agent phải infer tháng gần nhất. |
| **Gold SQL** | ```sql SELECT COALESCE(REGION, 'Unknown') AS region, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS active_users FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' AND MAU_TYPE != '0.Churn' GROUP BY COALESCE(REGION, 'Unknown') ORDER BY active_users DESC LIMIT 5 ``` |
| **Gold Result (summary)** | 5 rows — top 5 regions |
| **Expected Row Count** | 5 |

---

## Q007

| Field | Value |
|-------|-------|
| **ID** | Q007 |
| **Question (NL)** | Tiền rút ra nhiều hơn tiền gửi vào không? Tháng 2 |
| **Category** | Multi-step |
| **Difficulty** | Complex |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | Tất cả 7 cashin + 7 cashout sub-channels, GRASS_DATE |
| **Business Rules / Notes** | Net cash = Total Cashin - Total Cashout. Phải SUM đủ 7+7 sub-channels, mỗi cái COALESCE. Câu hỏi hỏi yes/no nhưng SQL cần tính cả 2 phía. Nếu chỉ dùng cashin_gmv và cashout_gmv → miss ~50% flow, có thể sai direction. |
| **Gold SQL** | ```sql SELECT SUM( COALESCE(cashin_gmv, 0) + COALESCE(cashin_p2p_gmv, 0) + COALESCE(cashin_va_gmv, 0) + COALESCE(cashin_ai_gmv, 0) + COALESCE(cashin_stock_gmv, 0) + COALESCE(cashin_payout_gmv, 0) + COALESCE(cashin_mp_gmv, 0) ) AS total_cashin, SUM( COALESCE(cashout_gmv, 0) + COALESCE(cashout_napas_gmv, 0) + COALESCE(cashout_p2p_gmv, 0) + COALESCE(cashout_payment_gmv, 0) + COALESCE(cashout_stock_gmv, 0) + COALESCE(cashout_mp_gmv, 0) + COALESCE(cashout_payment_mp_gmv, 0) ) AS total_cashout FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' ``` |
| **Gold Result (summary)** | 1 row: total_cashin vs total_cashout, net cash = cashin - cashout |
| **Expected Row Count** | 1 |

---

## Q008

| Field | Value |
|-------|-------|
| **ID** | Q008 |
| **Question (NL)** | Nhóm tuổi nào gửi tiết kiệm TTT nhiều nhất? |
| **Category** | Aggregation |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | AGE_GROUP, BALANCE, GRASS_DATE |
| **Business Rules / Notes** | "Gửi tiết kiệm nhiều nhất" có thể hiểu là total AUM hoặc total cashin — ambiguous nhẹ. AGE_GROUP format: '1.Below 22', '2.23-27', '3.28-35', '4.36-50', '5.Above 50'. Nên dùng AUM snapshot cuối tháng (default interpretation). ORDER BY DESC, không cần LIMIT (chỉ ~5-6 groups). |
| **Gold SQL** | ```sql SELECT AGE_GROUP, SUM(BALANCE) AS total_aum, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS user_count FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE = '2026-01-31' AND BALANCE > 0 GROUP BY AGE_GROUP ORDER BY total_aum DESC ``` |
| **Gold Result (summary)** | ~5-6 rows, sorted by AUM desc |
| **Expected Row Count** | 5-6 |

---

## Q009

| Field | Value |
|-------|-------|
| **ID** | Q009 |
| **Question (NL)** | Bao nhiêu % user TTT đang dùng Túi+? |
| **Category** | Conditional Logic |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | PLUS_TYPE, USER_ID, MAU_TYPE, GRASS_DATE |
| **Business Rules / Notes** | Túi+ users = PLUS_TYPE NOT IN ('0.Churn', 'None') AND PLUS_TYPE IS NOT NULL. Base = MAU (MAU_TYPE != '0.Churn'). REGEXP_EXTRACT cả tử lẫn mẫu. LLM thường không biết filter logic của PLUS_TYPE — dễ include churn Túi+ hoặc 'None' value. |
| **Gold SQL** | ```sql SELECT COUNT(DISTINCT CASE WHEN PLUS_TYPE NOT IN ('0.Churn', 'None') AND PLUS_TYPE IS NOT NULL THEN CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) END) * 100.0 / NULLIF(COUNT(DISTINCT CASE WHEN MAU_TYPE != '0.Churn' THEN CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) END), 0) AS tui_plus_pct FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-01-01' AND '2026-01-31' ``` |
| **Gold Result (summary)** | 1 row, tui_plus_pct (%) |
| **Expected Row Count** | 1 |

---

## Q010

| Field | Value |
|-------|-------|
| **ID** | Q010 |
| **Question (NL)** | Người dùng rút tiền từ TTT chủ yếu qua kênh nào? |
| **Category** | Ranking + Filter |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | cashout_gmv, cashout_napas_gmv, cashout_p2p_gmv, cashout_payment_gmv, cashout_stock_gmv, cashout_mp_gmv, cashout_payment_mp_gmv, GRASS_DATE |
| **Business Rules / Notes** | Cần breakdown 7 cashout sub-channels để so sánh. "Chủ yếu" = channel có GMV cao nhất. LLM thường chỉ biết cashout_gmv, không biết 6 kênh còn lại. Format output nên UNPIVOT hoặc liệt kê từng kênh. COALESCE. |
| **Gold SQL** | ```sql SELECT 'basic' AS channel, SUM(COALESCE(cashout_gmv, 0)) AS gmv FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' UNION ALL SELECT 'napas', SUM(COALESCE(cashout_napas_gmv, 0)) FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' UNION ALL SELECT 'p2p', SUM(COALESCE(cashout_p2p_gmv, 0)) FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' UNION ALL SELECT 'payment', SUM(COALESCE(cashout_payment_gmv, 0)) FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' UNION ALL SELECT 'stock', SUM(COALESCE(cashout_stock_gmv, 0)) FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' UNION ALL SELECT 'money_pool', SUM(COALESCE(cashout_mp_gmv, 0)) FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' UNION ALL SELECT 'payment_mp', SUM(COALESCE(cashout_payment_mp_gmv, 0)) FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' ORDER BY gmv DESC ``` |
| **Gold Result (summary)** | 7 rows, sorted by GMV desc — top channel likely p2p or payment |
| **Expected Row Count** | 7 |

---

## Q011

| Field | Value |
|-------|-------|
| **ID** | Q011 |
| **Question (NL)** | User mới tháng này so tháng trước tăng hay giảm? Giảm bao nhiêu? |
| **Category** | Date/Time |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | USER_ID, MAU_TYPE, GRASS_DATE |
| **Business Rules / Notes** | "User mới" = MAU_TYPE = '1.New' (KHÔNG phải != '0.Churn'). "Tháng này" vs "tháng trước" → agent phải infer relative dates. Cần REGEXP_EXTRACT. Dùng DATE_TRUNC(GRASS_DATE, MONTH) — KHÔNG dùng GRASS_MONTH (không tồn tại). LLM hay nhầm MAU_TYPE != '0.Churn' (= tất cả active, gồm retain + reactive) vs = '1.New' (chỉ new). |
| **Gold SQL** | ```sql WITH monthly_new AS ( SELECT DATE_TRUNC(GRASS_DATE, MONTH) AS month, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS new_users FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-01-01' AND '2026-02-28' AND MAU_TYPE = '1.New' GROUP BY DATE_TRUNC(GRASS_DATE, MONTH) ) SELECT *, LAG(new_users) OVER (ORDER BY month) AS prev_month, new_users - LAG(new_users) OVER (ORDER BY month) AS diff FROM monthly_new ``` |
| **Gold Result (summary)** | 2 rows: Jan + Feb new user counts with diff |
| **Expected Row Count** | 2 |

---

## Q012

| Field | Value |
|-------|-------|
| **ID** | Q012 |
| **Question (NL)** | Góp chung (Money Pool) đang chiếm bao nhiêu % tổng AUM? |
| **Category** | Aggregation |
| **Difficulty** | Simple |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | IS_MP, BALANCE, GRASS_DATE |
| **Business Rules / Notes** | IS_MP = 'Money Pool' vs 'Individual'. AUM = snapshot cuối tháng. % = Money Pool AUM / Total AUM * 100. LLM có thể không biết column IS_MP tồn tại hoặc dùng sai filter. Nếu SUM across month → sai 30x nhưng tỷ lệ % có thể vẫn gần đúng (trap tinh vi). |
| **Gold SQL** | ```sql SELECT IS_MP, SUM(BALANCE) AS aum, SUM(BALANCE) * 100.0 / SUM(SUM(BALANCE)) OVER () AS pct FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE = '2026-01-31' GROUP BY IS_MP ``` |
| **Gold Result (summary)** | 2 rows: Individual ~86%, Money Pool ~14% |
| **Expected Row Count** | 2 |

---

## Q013

| Field | Value |
|-------|-------|
| **ID** | Q013 |
| **Question (NL)** | Mấy ngày đầu tháng 3 có gì bất thường không? Nhìn dòng tiền dùm t |
| **Category** | Window + Complex |
| **Difficulty** | Complex |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | Tất cả cashin + cashout sub-channels, GRASS_DATE |
| **Business Rules / Notes** | "Mấy ngày đầu tháng 3" = 2026-03-01 đến ~03-08 (data available). "Bất thường" = anomaly detection → cần tính daily totals + compare vs baseline (mean, stddev). Known: Mar 7 (Z=+6.4σ) và Mar 8 (Z=+7.6σ) cashout spikes. Net cash -416B (anomaly lịch sử). Agent cần chạy daily breakdown + statistical comparison, không chỉ SUM tổng. |
| **Gold SQL** | ```sql WITH daily AS ( SELECT GRASS_DATE, SUM(COALESCE(cashin_gmv,0)+COALESCE(cashin_p2p_gmv,0)+COALESCE(cashin_va_gmv,0)+COALESCE(cashin_ai_gmv,0)+COALESCE(cashin_stock_gmv,0)+COALESCE(cashin_payout_gmv,0)+COALESCE(cashin_mp_gmv,0)) AS cashin, SUM(COALESCE(cashout_gmv,0)+COALESCE(cashout_napas_gmv,0)+COALESCE(cashout_p2p_gmv,0)+COALESCE(cashout_payment_gmv,0)+COALESCE(cashout_stock_gmv,0)+COALESCE(cashout_mp_gmv,0)+COALESCE(cashout_payment_mp_gmv,0)) AS cashout FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-03-01' AND '2026-03-08' GROUP BY GRASS_DATE ) SELECT *, cashin - cashout AS net, AVG(cashout) OVER () AS avg_cashout, ROUND((cashout - AVG(cashout) OVER ()) / NULLIF(STDDEV(cashout) OVER (), 0), 2) AS z_score FROM daily ORDER BY GRASS_DATE ``` |
| **Gold Result (summary)** | 8 rows daily, Mar 7-8 có Z-score cao bất thường |
| **Expected Row Count** | 8 |

---

## Q014

| Field | Value |
|-------|-------|
| **ID** | Q014 |
| **Question (NL)** | Tỷ lệ churn TTT đang bao nhiêu? Có cao hơn bình thường không? |
| **Category** | Multi-step |
| **Difficulty** | Complex |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | USER_ID, MAU_TYPE, GRASS_DATE |
| **Business Rules / Notes** | Churn = MAU_TYPE = '0.Churn'. Total base = ALL unique users (cả churn + active). Churn rate = churn/total * 100. Pool churn rất lớn (~75-77%) — đây là bình thường cho TTT. "Cao hơn bình thường" cần so sánh vs tháng trước hoặc baseline → multi-step. REGEXP_EXTRACT bắt buộc. |
| **Gold SQL** | ```sql WITH monthly_churn AS ( SELECT DATE_TRUNC(GRASS_DATE, MONTH) AS month, COUNT(DISTINCT CASE WHEN MAU_TYPE = '0.Churn' THEN CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) END) AS churned, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS total FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2025-12-01' AND '2026-01-31' GROUP BY DATE_TRUNC(GRASS_DATE, MONTH) ) SELECT month, churned, total, ROUND(churned * 100.0 / NULLIF(total, 0), 2) AS churn_rate_pct FROM monthly_churn ORDER BY month ``` |
| **Gold Result (summary)** | 2 rows (Dec 2025, Jan 2026), churn_rate ~75-77% |
| **Expected Row Count** | 2 |

---

## Q015

| Field | Value |
|-------|-------|
| **ID** | Q015 |
| **Question (NL)** | Năm ngoái cùng kỳ AUM là bao nhiêu? Tăng trưởng YoY? |
| **Category** | Date/Time |
| **Difficulty** | Complex |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | BALANCE, GRASS_DATE |
| **Business Rules / Notes** | "Cùng kỳ" = same month last year. "Năm ngoái" relative → agent phải infer. Cả 2 thời điểm đều cần end-of-month snapshot. YoY = (current - prev) / prev * 100. Nếu 2025 data không có → cần handle gracefully. |
| **Gold SQL** | ```sql WITH aum AS ( SELECT EXTRACT(YEAR FROM GRASS_DATE) AS yr, SUM(BALANCE) AS total_aum FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE IN ('2025-01-31', '2026-01-31') GROUP BY EXTRACT(YEAR FROM GRASS_DATE) ) SELECT curr.total_aum AS aum_2026, prev.total_aum AS aum_2025, ROUND((curr.total_aum - prev.total_aum) / NULLIF(prev.total_aum, 0) * 100, 2) AS yoy_pct FROM aum curr JOIN aum prev ON curr.yr = 2026 AND prev.yr = 2025 ``` |
| **Gold Result (summary)** | 1 row: AUM 2026, AUM 2025, YoY growth % |
| **Expected Row Count** | 1 |

---

## Q016

| Field | Value |
|-------|-------|
| **ID** | Q016 |
| **Question (NL)** | Trong số người bỏ TTT tháng 1, trước đó họ có gửi tiền không hay chỉ mở rồi bỏ? |
| **Category** | Subquery |
| **Difficulty** | Complex |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | USER_ID, MAU_TYPE, MFU_TYPE, GRASS_DATE |
| **Business Rules / Notes** | "Bỏ TTT" = MAU_TYPE = '0.Churn' trong tháng 1/2026. "Trước đó có gửi tiền" = từng có MFU_TYPE != '0.Churn' trong tháng 12/2025. Cần subquery/CTE: tìm churned users tháng 1, check xem họ có funded ở tháng 12 không. Chia thành 2 nhóm: từng funded vs chưa bao giờ funded. REGEXP_EXTRACT bắt buộc. |
| **Gold SQL** | ```sql WITH jan_churn AS ( SELECT DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) AS uid FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-01-01' AND '2026-01-31' AND MAU_TYPE = '0.Churn' ), dec_funded AS ( SELECT DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) AS uid FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2025-12-01' AND '2025-12-31' AND MFU_TYPE != '0.Churn' ) SELECT CASE WHEN d.uid IS NOT NULL THEN 'Previously Funded' ELSE 'Never Funded' END AS segment, COUNT(*) AS user_count FROM jan_churn j LEFT JOIN dec_funded d ON j.uid = d.uid GROUP BY CASE WHEN d.uid IS NOT NULL THEN 'Previously Funded' ELSE 'Never Funded' END ``` |
| **Gold Result (summary)** | 2 rows: Previously Funded vs Never Funded counts |
| **Expected Row Count** | 2 |

---

## Q017

| Field | Value |
|-------|-------|
| **ID** | Q017 |
| **Question (NL)** | Nam hay nữ tiết kiệm giỏi hơn? |
| **Category** | Aggregation |
| **Difficulty** | Simple |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | GENDER, BALANCE, USER_ID, GRASS_DATE |
| **Business Rules / Notes** | "Tiết kiệm giỏi hơn" = avg balance per user. GENDER = 'male', 'female', 'unknown'. Dùng end-of-month snapshot. Chỉ MFU (có tiền) để avg không bị pha loãng bởi churn users có balance = 0. COALESCE(GENDER, 'unknown'). LLM có thể quên filter MFU hoặc dùng SUM thay AVG. |
| **Gold SQL** | ```sql SELECT COALESCE(GENDER, 'unknown') AS gender, AVG(BALANCE) AS avg_balance_per_user, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS users FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE = '2026-01-31' AND MFU_TYPE != '0.Churn' GROUP BY COALESCE(GENDER, 'unknown') ORDER BY avg_balance_per_user DESC ``` |
| **Gold Result (summary)** | 3 rows (male, female, unknown), sorted by avg_balance |
| **Expected Row Count** | 3 |

---

## Q018

| Field | Value |
|-------|-------|
| **ID** | Q018 |
| **Question (NL)** | Q4/2025 so với Q3/2025, AUM tăng bao nhiêu tỷ? MAU tăng bao nhiêu người? |
| **Category** | Date/Time |
| **Difficulty** | Complex |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | BALANCE, USER_ID, MAU_TYPE, GRASS_DATE |
| **Business Rules / Notes** | AUM = end-of-quarter snapshot (cuối Sep vs cuối Dec). MAU = full quarter range, dedup REGEXP_EXTRACT, filter MAU_TYPE != '0.Churn'. Hai metrics cần date logic hoàn toàn khác nhau trong cùng 1 query. Q3 end = 2025-09-30, Q4 end = 2025-12-31. LLM thường apply cùng date logic cho cả AUM và MAU. |
| **Gold SQL** | ```sql WITH aum AS ( SELECT CASE WHEN GRASS_DATE = '2025-09-30' THEN 'Q3' ELSE 'Q4' END AS quarter, SUM(BALANCE) AS aum FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE IN ('2025-09-30', '2025-12-31') GROUP BY CASE WHEN GRASS_DATE = '2025-09-30' THEN 'Q3' ELSE 'Q4' END ), mau AS ( SELECT CASE WHEN GRASS_DATE <= '2025-09-30' THEN 'Q3' ELSE 'Q4' END AS quarter, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS mau FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2025-07-01' AND '2025-12-31' AND MAU_TYPE != '0.Churn' GROUP BY CASE WHEN GRASS_DATE <= '2025-09-30' THEN 'Q3' ELSE 'Q4' END ) SELECT a.quarter, a.aum, m.mau FROM aum a JOIN mau m ON a.quarter = m.quarter ORDER BY a.quarter ``` |
| **Gold Result (summary)** | 2 rows (Q3, Q4), mỗi row có AUM + MAU → diff tính thủ công |
| **Expected Row Count** | 2 |

---

## Q019

| Field | Value |
|-------|-------|
| **ID** | Q019 |
| **Question (NL)** | Trong tháng 1, ngày nào có nhiều người rút tiền nhất? Rút bao nhiêu? |
| **Category** | Ranking + Filter |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | GRASS_DATE, USER_ID, cashout sub-channels |
| **Business Rules / Notes** | "Nhiều người rút" = COUNT DISTINCT users có cashout > 0 (bất kỳ sub-channel nào). "Rút bao nhiêu" = total cashout GMV ngày đó (SUM tất cả 7 sub-channels). Cần cả 2 metrics: user count + GMV. Chỉ count users có ít nhất 1 cashout sub-channel > 0. REGEXP_EXTRACT. LLM thường chỉ trả GMV hoặc chỉ trả user count, không cả 2. |
| **Gold SQL** | ```sql SELECT GRASS_DATE, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS users_withdrawing, SUM( COALESCE(cashout_gmv, 0) + COALESCE(cashout_napas_gmv, 0) + COALESCE(cashout_p2p_gmv, 0) + COALESCE(cashout_payment_gmv, 0) + COALESCE(cashout_stock_gmv, 0) + COALESCE(cashout_mp_gmv, 0) + COALESCE(cashout_payment_mp_gmv, 0) ) AS total_cashout FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-01-01' AND '2026-01-31' AND ( COALESCE(cashout_gmv, 0) + COALESCE(cashout_napas_gmv, 0) + COALESCE(cashout_p2p_gmv, 0) + COALESCE(cashout_payment_gmv, 0) + COALESCE(cashout_stock_gmv, 0) + COALESCE(cashout_mp_gmv, 0) + COALESCE(cashout_payment_mp_gmv, 0) ) > 0 GROUP BY GRASS_DATE ORDER BY users_withdrawing DESC LIMIT 1 ``` |
| **Gold Result (summary)** | 1 row: ngày peak + user count + total cashout GMV |
| **Expected Row Count** | 1 |

---

## Q020

| Field | Value |
|-------|-------|
| **ID** | Q020 |
| **Question (NL)** | TTT tháng vừa rồi ổn không? Brief cho t ngắn gọn |
| **Category** | Ambiguous |
| **Difficulty** | Ambiguous |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | Potentially ALL |
| **Business Rules / Notes** | Câu hỏi executive-style cực kỳ vague. "Tháng vừa rồi" = tháng nào? "Ổn không" = theo tiêu chí gì? Agent tốt nên: (1) clarify hoặc (2) decompose thành ≥3 metrics: MAU trend, AUM, net cash flow, churn. Nếu chỉ trả 1 metric → incomplete. Nếu tháng 3/2026 → net cash -416B là critical insight. Agent đúng khi hỏi ngược: "Anh muốn t nhìn vào chỉ số nào? MAU, AUM, hay dòng tiền?". |
| **Gold SQL** | ```sql -- Không có single Gold SQL -- Agent tốt: hỏi lại HOẶC chạy ≥3 queries: -- 1. MAU (with REGEXP_EXTRACT + MAU_TYPE filter) -- 2. AUM (end-of-month snapshot) -- 3. Net cash flow (full cashin - cashout sub-channels) -- 4. Churn rate (optional) ``` |
| **Gold Result (summary)** | Multi-query needed. Key: nếu Feb thì relatively stable; nếu Mar thì net cash -416B red flag |
| **Expected Row Count** | N/A |

---

---
---

# BATCH 2: Câu hỏi tự nhiên kiểu Slack/meeting (Q021–Q040)

> Batch này viết đúng kiểu stakeholder chat nhanh: không dấu, viết tắt, thiếu context, hỏi "tại sao", hỏi hành vi, hỏi thứ không có trong schema.

---

## Q021

| Field | Value |
|-------|-------|
| **ID** | Q021 |
| **Question (NL)** | user ttt giu tien bao lau truoc khi rut ra het? |
| **Category** | Window + Complex |
| **Difficulty** | Complex |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | USER_ID, BALANCE, MFU_TYPE, GRASS_DATE |
| **Business Rules / Notes** | Câu hỏi hành vi duration — cần tính khoảng cách ngày từ lúc user bắt đầu có balance > 0 đến khi balance = 0. Table là daily snapshot nên phải self-join hoặc window function để tìm "first funded date" vs "last funded date" per user. Rất phức tạp: cần xác định "episode" nạp-rút, không phải chỉ min/max date. LLM sẽ gần như chắc chắn oversimplify hoặc viết sai logic. Có thể cần approximate bằng cách tính avg số ngày MFU_TYPE != '0.Churn' liên tiếp. |
| **Gold SQL** | ```sql -- Approximate: avg number of consecutive funded days per user WITH funded_days AS ( SELECT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) AS uid, GRASS_DATE, MFU_TYPE, LAG(GRASS_DATE) OVER (PARTITION BY CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) ORDER BY GRASS_DATE) AS prev_date FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-01-01' AND '2026-01-31' AND MFU_TYPE != '0.Churn' ), with_gaps AS ( SELECT uid, GRASS_DATE, CASE WHEN DATE_DIFF(GRASS_DATE, prev_date, DAY) > 1 OR prev_date IS NULL THEN 1 ELSE 0 END AS new_episode FROM funded_days ), episodes AS ( SELECT uid, GRASS_DATE, SUM(new_episode) OVER (PARTITION BY uid ORDER BY GRASS_DATE) AS episode_id FROM with_gaps ), episode_length AS ( SELECT uid, episode_id, DATE_DIFF(MAX(GRASS_DATE), MIN(GRASS_DATE), DAY) + 1 AS days_held FROM episodes GROUP BY uid, episode_id ) SELECT AVG(days_held) AS avg_days_before_withdraw, APPROX_QUANTILES(days_held, 100)[OFFSET(50)] AS median_days FROM episode_length ``` |
| **Gold Result (summary)** | 1 row: avg + median days users hold money before withdrawing |
| **Expected Row Count** | 1 |

---

## Q022

| Field | Value |
|-------|-------|
| **ID** | Q022 |
| **Question (NL)** | tai sao aum giam thang nay? |
| **Category** | Ambiguous |
| **Difficulty** | Ambiguous |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | BALANCE, GRASS_DATE, cashin/cashout sub-channels, MAU_TYPE, MFU_TYPE |
| **Business Rules / Notes** | Câu hỏi causal ("tại sao") — SQL không trả lời được "tại sao", chỉ trả lời "cái gì xảy ra". Agent tốt nên: (1) Xác nhận AUM giảm thật không (snapshot cuối tháng so sánh), (2) Decompose các yếu tố: net cash flow giảm? user churn tăng? cashin giảm? cashout tăng? (3) Trả lời bằng data rồi interpret. "Tháng này" không rõ tháng nào. LLM sẽ fail nếu chỉ gen 1 query đơn giản. |
| **Gold SQL** | ```sql -- Cần multi-query decomposition. Minimum: -- 1. AUM comparison (2 tháng gần nhất, end-of-month snapshot) -- 2. Net cash flow breakdown (cashin vs cashout, all sub-channels) -- 3. MFU churn (người rút hết tiền) -- Không có single SQL answer cho "tại sao" ``` |
| **Gold Result (summary)** | Multi-query. Agent tốt nhất nên hỏi lại "tháng nào?" rồi decompose |
| **Expected Row Count** | N/A |

---

## Q023

| Field | Value |
|-------|-------|
| **ID** | Q023 |
| **Question (NL)** | moi thang co bao nhieu nguoi nap VA tren 10 giao dich 1 ngay? |
| **Category** | Aggregation |
| **Difficulty** | Complex |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | USER_ID, CASHIN_VA_TRANS, GRASS_DATE |
| **Business Rules / Notes** | "Nạp VA" = Virtual Account cashin. "Trên 10 giao dịch 1 ngày" = CASHIN_VA_TRANS > 10 per row (vì mỗi row = 1 user/1 ngày). Cần GROUP BY tháng, COUNT DISTINCT user có ít nhất 1 ngày CASHIN_VA_TRANS > 10. REGEXP_EXTRACT cho dedup. Câu hỏi cụ thể nhưng dùng column TRANS (không phải GMV) — LLM thường chỉ biết GMV columns. "Mỗi tháng" = cần multi-month, không nói range → agent phải infer. |
| **Gold SQL** | ```sql SELECT DATE_TRUNC(GRASS_DATE, MONTH) AS month, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS users_over_10_va_trans FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2025-10-01' AND '2026-02-28' AND CASHIN_VA_TRANS > 10 GROUP BY DATE_TRUNC(GRASS_DATE, MONTH) ORDER BY month ``` |
| **Gold Result (summary)** | ~5 rows (1 per month), count users with >10 VA transactions in a single day |
| **Expected Row Count** | 5 |

---

## Q024

| Field | Value |
|-------|-------|
| **ID** | Q024 |
| **Question (NL)** | hanh vi nap rut cua tui cong khac gi so voi tui ca nhan 30 ngay qua? |
| **Category** | Multi-step |
| **Difficulty** | Complex |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | IS_MP, tất cả cashin + cashout sub-channels + TRANS columns, GRASS_DATE |
| **Business Rules / Notes** | "Túi cộng" = Money Pool (IS_MP = 'Money Pool'). "Túi cá nhân" = Individual. "30 ngày qua" = relative date. "Hành vi nạp rút" = cần cả GMV lẫn transaction count, breakdown by channel. Cần GROUP BY IS_MP với tất cả sub-channels. LLM sẽ: (1) không biết IS_MP column, (2) thiếu sub-channels, (3) chỉ lấy GMV không lấy TRANS. |
| **Gold SQL** | ```sql SELECT IS_MP, SUM(COALESCE(cashin_gmv,0)+COALESCE(cashin_p2p_gmv,0)+COALESCE(cashin_va_gmv,0)+COALESCE(cashin_ai_gmv,0)+COALESCE(cashin_stock_gmv,0)+COALESCE(cashin_payout_gmv,0)+COALESCE(cashin_mp_gmv,0)) AS total_cashin_gmv, SUM(COALESCE(CASHIN_TRANS,0)+COALESCE(CASHIN_P2P_TRANS,0)+COALESCE(CASHIN_VA_TRANS,0)+COALESCE(CASHIN_AI_TRANS,0)+COALESCE(CASHIN_STOCK_TRANS,0)+COALESCE(CASHIN_PAYOUT_TRANS,0)+COALESCE(CASHIN_MP_TRANS,0)) AS total_cashin_trans, SUM(COALESCE(cashout_gmv,0)+COALESCE(cashout_napas_gmv,0)+COALESCE(cashout_p2p_gmv,0)+COALESCE(cashout_payment_gmv,0)+COALESCE(cashout_stock_gmv,0)+COALESCE(cashout_mp_gmv,0)+COALESCE(cashout_payment_mp_gmv,0)) AS total_cashout_gmv, SUM(COALESCE(CASHOUT_TRANS,0)+COALESCE(CASHOUT_NAPAS_TRANS,0)+COALESCE(CASHOUT_P2P_TRANS,0)+COALESCE(CASHOUT_PAYMENT_TRANS,0)+COALESCE(CASHOUT_STOCK_TRANS,0)+COALESCE(CASHOUT_MP_TRANS,0)+COALESCE(CASHOUT_PAYMENT_MP_TRANS,0)) AS total_cashout_trans FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) GROUP BY IS_MP ``` |
| **Gold Result (summary)** | 2 rows (Individual, Money Pool): cashin/cashout GMV + trans counts |
| **Expected Row Count** | 2 |

---

## Q025

| Field | Value |
|-------|-------|
| **ID** | Q025 |
| **Question (NL)** | nguoi dung mua tui cong thi sau do lam gi? |
| **Category** | Ambiguous |
| **Difficulty** | Ambiguous |
| **Target Tables** | fact_ttt_event_tracking, mart_ttt_daily_user_record |
| **Target Columns** | event_name, screen_name, USER_ID, IS_MP, GRASS_DATE |
| **Business Rules / Notes** | Câu hỏi journey/funnel — "mua túi cộng" = kích hoạt Money Pool, "sau đó làm gì" = cần xem event sequence sau activation. Cần JOIN event tracking table với mart table. Không rõ timeframe. Agent tốt nên hỏi lại: "Anh muốn xem hành vi trong bao lâu sau khi kích hoạt? Và đo bằng metric nào — screen views, transactions, hay balance?". LLM gần chắc không biết cách map "mua túi cộng" → event nào. |
| **Gold SQL** | ```sql -- Cần event tracking data -- Agent nên hỏi lại clarify -- Approximate: xem cashin/cashout pattern của Money Pool users SELECT DATE_TRUNC(GRASS_DATE, MONTH) AS month, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS mp_users, SUM(COALESCE(cashin_mp_gmv, 0)) AS mp_cashin, SUM(COALESCE(cashout_mp_gmv, 0)) AS mp_cashout, SUM(COALESCE(cashout_payment_mp_gmv, 0)) AS mp_payment FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE IS_MP = 'Money Pool' AND MAU_TYPE = '1.New' AND GRASS_DATE BETWEEN '2025-10-01' AND '2026-02-28' GROUP BY DATE_TRUNC(GRASS_DATE, MONTH) ORDER BY month ``` |
| **Gold Result (summary)** | Agent nên clarify. Nếu ép trả lời: ~5 rows monthly behavior of new MP users |
| **Expected Row Count** | ~5 |

---

## Q026

| Field | Value |
|-------|-------|
| **ID** | Q026 |
| **Question (NL)** | so du trung binh cua user ttt la bao nhieu? |
| **Category** | Aggregation |
| **Difficulty** | Simple |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | BALANCE, AVG_BALANCE, USER_ID, GRASS_DATE |
| **Business Rules / Notes** | Bẫy column: table có cả `BALANCE` (snapshot cuối ngày) và `AVG_BALANCE` (rolling 30-day avg). "Số dư trung bình" có thể hiểu là: (1) AVG(BALANCE) tại 1 ngày = trung bình trên tất cả users, (2) dùng column AVG_BALANCE = rolling avg per user. Cần clarify. Nếu dùng BALANCE, phải chọn 1 ngày (snapshot). Nên filter chỉ funded users (MFU_TYPE != '0.Churn') để avg không bị kéo xuống bởi hàng triệu users balance = 0. Không nói tháng nào. |
| **Gold SQL** | ```sql SELECT AVG(BALANCE) AS avg_balance_per_funded_user, SUM(BALANCE) AS total_aum, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS funded_users FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE = '2026-02-28' AND MFU_TYPE != '0.Churn' ``` |
| **Gold Result (summary)** | 1 row: avg ~6-7M VND per funded user |
| **Expected Row Count** | 1 |

---

## Q027

| Field | Value |
|-------|-------|
| **ID** | Q027 |
| **Question (NL)** | tui+ dang co bao nhieu nguoi? tang hay giam so thang truoc? |
| **Category** | Date/Time |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | PLUS_TYPE, USER_ID, GRASS_DATE |
| **Business Rules / Notes** | Túi+ users = PLUS_TYPE NOT IN ('0.Churn', 'None') AND IS NOT NULL. Cần 2 tháng để compare. REGEXP_EXTRACT. "Tháng trước" = relative. LLM trap: (1) filter PLUS_TYPE sai, (2) thiếu dedup, (3) không biết phải so 2 tháng. |
| **Gold SQL** | ```sql SELECT DATE_TRUNC(GRASS_DATE, MONTH) AS month, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS tui_plus_users FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-01-01' AND '2026-02-28' AND PLUS_TYPE NOT IN ('0.Churn', 'None') AND PLUS_TYPE IS NOT NULL GROUP BY DATE_TRUNC(GRASS_DATE, MONTH) ORDER BY month ``` |
| **Gold Result (summary)** | 2 rows (Jan, Feb): Túi+ user counts |
| **Expected Row Count** | 2 |

---

## Q028

| Field | Value |
|-------|-------|
| **ID** | Q028 |
| **Question (NL)** | user nao dang giu nhieu tien nhat trong ttt? top 10 |
| **Category** | Ranking + Filter |
| **Difficulty** | Simple |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | USER_ID, BALANCE, GRASS_DATE |
| **Business Rules / Notes** | Top 10 users by BALANCE tại ngày gần nhất (snapshot). Cần ORDER BY BALANCE DESC LIMIT 10. Không cần REGEXP_EXTRACT ở đây vì muốn xem account-level. Nhưng nên dùng end-of-month snapshot. Câu đơn giản nhưng LLM có thể: (1) SUM across days, (2) không chọn đúng date. |
| **Gold SQL** | ```sql SELECT USER_ID, IS_MP, BALANCE FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE = '2026-02-28' ORDER BY BALANCE DESC LIMIT 10 ``` |
| **Gold Result (summary)** | 10 rows: top 10 users by balance |
| **Expected Row Count** | 10 |

---

## Q029

| Field | Value |
|-------|-------|
| **ID** | Q029 |
| **Question (NL)** | tai sao thang nay user nap nhieu tien hon binh thuong? |
| **Category** | Ambiguous |
| **Difficulty** | Ambiguous |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | cashin sub-channels, GRASS_DATE, CASHIN_VA_TRANS, AGE_GROUP, REGION |
| **Business Rules / Notes** | Causal question lần nữa. "Nạp nhiều hơn bình thường" = trước tiên phải xác nhận cashin thực sự tăng (so vs baseline). Sau đó decompose: kênh nào tăng? nhóm user nào nạp nhiều hơn? region nào? Agent không thể trả lời "tại sao" chỉ bằng SQL — chỉ có thể show "cái gì thay đổi". "Tháng này" = không rõ. LLM sẽ fail nếu gen 1 query. |
| **Gold SQL** | ```sql -- Multi-query decomposition needed: -- 1. Confirm: tổng cashin tháng này vs avg 3 tháng trước -- 2. Breakdown by channel: kênh nào spike -- 3. Breakdown by segment: AGE_GROUP, REGION, BAL_GROUP -- Example query 1: cashin trend WITH monthly AS ( SELECT DATE_TRUNC(GRASS_DATE, MONTH) AS month, SUM(COALESCE(cashin_gmv,0)+COALESCE(cashin_p2p_gmv,0)+COALESCE(cashin_va_gmv,0)+COALESCE(cashin_ai_gmv,0)+COALESCE(cashin_stock_gmv,0)+COALESCE(cashin_payout_gmv,0)+COALESCE(cashin_mp_gmv,0)) AS total_cashin FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2025-11-01' AND '2026-02-28' GROUP BY DATE_TRUNC(GRASS_DATE, MONTH) ) SELECT *, LAG(total_cashin) OVER (ORDER BY month) AS prev_month, ROUND((total_cashin - LAG(total_cashin) OVER (ORDER BY month)) / NULLIF(LAG(total_cashin) OVER (ORDER BY month), 0) * 100, 2) AS mom_change_pct FROM monthly ORDER BY month ``` |
| **Gold Result (summary)** | ~4 rows monthly cashin trend. Agent nên follow up với channel/segment breakdown |
| **Expected Row Count** | 4 |

---

## Q030

| Field | Value |
|-------|-------|
| **ID** | Q030 |
| **Question (NL)** | user tui+ rut tien ve ngan hang (napas) thang roi bao nhieu? co tang khong? |
| **Category** | Conditional Logic |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | PLUS_TYPE, IS_CASHOUT_NAPAS, CASHOUT_NAPAS_GMV, CASHOUT_NAPAS_TRANS, GRASS_DATE, USER_ID |
| **Business Rules / Notes** | Túi+ filter: PLUS_TYPE NOT IN ('0.Churn', 'None'). Napas = cashout_napas_gmv. "Có tăng không" = cần so 2 tháng. Có thể dùng IS_CASHOUT_NAPAS = 'Cashout' hoặc trực tiếp filter cashout_napas_gmv > 0. REGEXP_EXTRACT. LLM trap: (1) không biết PLUS_TYPE filter, (2) không biết IS_CASHOUT_NAPAS tag. |
| **Gold SQL** | ```sql SELECT DATE_TRUNC(GRASS_DATE, MONTH) AS month, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS napas_users, SUM(COALESCE(CASHOUT_NAPAS_GMV, 0)) AS napas_gmv, SUM(COALESCE(CASHOUT_NAPAS_TRANS, 0)) AS napas_trans FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-01-01' AND '2026-02-28' AND PLUS_TYPE NOT IN ('0.Churn', 'None') AND PLUS_TYPE IS NOT NULL GROUP BY DATE_TRUNC(GRASS_DATE, MONTH) ORDER BY month ``` |
| **Gold Result (summary)** | 2 rows (Jan, Feb): napas users + GMV + trans for Túi+ users |
| **Expected Row Count** | 2 |

---

## Q031

| Field | Value |
|-------|-------|
| **ID** | Q031 |
| **Question (NL)** | tinh hinh kinh doanh ttt 6 thang qua |
| **Category** | Ambiguous |
| **Difficulty** | Ambiguous |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | Potentially ALL key metrics |
| **Business Rules / Notes** | Cực kỳ vague — giống Q020 nhưng timeframe dài hơn. "Tình hình kinh doanh" = executive dashboard gồm: MAU, MFU, AUM, cashin, cashout, net cash, churn, new users, interest cost. Mỗi metric cần date logic khác nhau. 6 tháng = Sep 2025 – Feb 2026. Agent đúng nếu hỏi lại "anh muốn focus vào metric nào?" hoặc tự decompose ≥4 metrics. |
| **Gold SQL** | ```sql -- Minimum viable: monthly trend cho 4 core metrics -- AUM (snapshot) + MAU (range) + cashin + cashout per month -- Mỗi metric cần query riêng do date logic khác nhau -- Ví dụ cho MAU trend: SELECT DATE_TRUNC(GRASS_DATE, MONTH) AS month, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS mau FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2025-09-01' AND '2026-02-28' AND MAU_TYPE != '0.Churn' GROUP BY DATE_TRUNC(GRASS_DATE, MONTH) ORDER BY month ``` |
| **Gold Result (summary)** | Multi-query, 6 rows per metric |
| **Expected Row Count** | N/A |

---

## Q032

| Field | Value |
|-------|-------|
| **ID** | Q032 |
| **Question (NL)** | nhom so du nao dong gop nhieu nhat vao tong AUM? |
| **Category** | Aggregation |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | BAL_GROUP, BALANCE, GRASS_DATE |
| **Business Rules / Notes** | BAL_GROUP = balance tier ([0]Churn, [1](0-300k], [2](300k-3TR], [3](3TR-30TR], [4](30TR-50TR], [5](50TR-100TR], [6](100TR-inf]). GROUP BY BAL_GROUP, SUM(BALANCE) at end-of-month. ORDER BY DESC. LLM có thể: (1) không biết BAL_GROUP column tồn tại → cố tạo CASE WHEN tự phân nhóm, (2) SUM across all days. |
| **Gold SQL** | ```sql SELECT BAL_GROUP, SUM(BALANCE) AS total_aum, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS user_count, ROUND(SUM(BALANCE) * 100.0 / SUM(SUM(BALANCE)) OVER (), 2) AS pct_of_total FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE = '2026-01-31' GROUP BY BAL_GROUP ORDER BY total_aum DESC ``` |
| **Gold Result (summary)** | ~7 rows (1 per BAL_GROUP), top tier likely [6](100TR-inf] |
| **Expected Row Count** | 7 |

---

## Q033

| Field | Value |
|-------|-------|
| **ID** | Q033 |
| **Question (NL)** | user tui+ duoc cashback bao nhieu roi? co dang khong? |
| **Category** | Aggregation |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | TOTAL_CASHBACK_GMV, TOTAL_CASHBACK_TRANS, IS_CASHBACK, PLUS_TYPE, GRASS_DATE, USER_ID |
| **Business Rules / Notes** | Cashback = quyền lợi Túi+ hoàn 0.1% khi thanh toán bằng TTT. Column: TOTAL_CASHBACK_GMV, TOTAL_CASHBACK_TRANS. Filter: IS_CASHBACK = 'Cashback' hoặc TOTAL_CASHBACK_GMV > 0. "Có đáng không" = cần tính tổng cashback vs tổng cashout_payment (chi phí cashback / revenue from payment). LLM gần chắc không biết columns TOTAL_CASHBACK_GMV và IS_CASHBACK tồn tại. |
| **Gold SQL** | ```sql SELECT DATE_TRUNC(GRASS_DATE, MONTH) AS month, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS cashback_users, SUM(COALESCE(TOTAL_CASHBACK_GMV, 0)) AS total_cashback, SUM(COALESCE(CASHOUT_PAYMENT_GMV, 0)) AS total_payment_gmv, ROUND(SUM(COALESCE(TOTAL_CASHBACK_GMV, 0)) * 100.0 / NULLIF(SUM(COALESCE(CASHOUT_PAYMENT_GMV, 0)), 0), 4) AS cashback_rate_pct FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-01-01' AND '2026-02-28' AND PLUS_TYPE NOT IN ('0.Churn', 'None') AND PLUS_TYPE IS NOT NULL GROUP BY DATE_TRUNC(GRASS_DATE, MONTH) ORDER BY month ``` |
| **Gold Result (summary)** | 2 rows: monthly cashback total + rate vs payment GMV |
| **Expected Row Count** | 2 |

---

## Q034

| Field | Value |
|-------|-------|
| **ID** | Q034 |
| **Question (NL)** | user nap tu dong (auto invest) co bao nhieu nguoi? nap trung binh bao nhieu? |
| **Category** | Aggregation |
| **Difficulty** | Simple |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | CASHIN_AI_TRANS, CASHIN_AI_GMV, USER_ID, GRASS_DATE |
| **Business Rules / Notes** | "Nạp tự động" = Auto Invest = cashin_ai columns. Filter: CASHIN_AI_TRANS > 0 hoặc CASHIN_AI_GMV > 0. Avg = tổng GMV / số unique users. REGEXP_EXTRACT. Không nói tháng nào. LLM trap: (1) không biết cashin_ai_gmv/trans columns, (2) nhầm với cashin_gmv. |
| **Gold SQL** | ```sql SELECT COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS ai_users, SUM(COALESCE(CASHIN_AI_GMV, 0)) AS total_ai_cashin, ROUND(SUM(COALESCE(CASHIN_AI_GMV, 0)) / NULLIF(COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)), 0), 0) AS avg_ai_cashin_per_user FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' AND CASHIN_AI_TRANS > 0 ``` |
| **Gold Result (summary)** | 1 row: AI users count + total + avg per user |
| **Expected Row Count** | 1 |

---

## Q035

| Field | Value |
|-------|-------|
| **ID** | Q035 |
| **Question (NL)** | user co so du tren 50 trieu chiem bao nhieu % tong? ho la ai? |
| **Category** | Conditional Logic |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | BALANCE, BAL_GROUP, USER_ID, GRASS_DATE, AGE_GROUP, GENDER, REGION |
| **Business Rules / Notes** | ">50 triệu" = BALANCE > 50000000 hoặc BAL_GROUP IN ('[5](50TR-100TR]', '[6](100TR-inf]'). "Chiếm bao nhiêu %" = % of total AUM hoặc % of total users (ambiguous). "Họ là ai" = demographic breakdown (age, gender, region). Cần snapshot cuối tháng. LLM có thể: (1) dùng sai threshold, (2) không biết BAL_GROUP, (3) chỉ trả % mà không trả demographics. |
| **Gold SQL** | ```sql WITH all_users AS ( SELECT SUM(BALANCE) AS total_aum, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS total_users FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE = '2026-01-31' AND BALANCE > 0 ), high_balance AS ( SELECT COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS hb_users, SUM(BALANCE) AS hb_aum FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE = '2026-01-31' AND BALANCE > 50000000 ), demographics AS ( SELECT AGE_GROUP, GENDER, COALESCE(REGION, 'Unknown') AS region, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS users FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE = '2026-01-31' AND BALANCE > 50000000 GROUP BY AGE_GROUP, GENDER, COALESCE(REGION, 'Unknown') ORDER BY users DESC LIMIT 10 ) SELECT hb.hb_users, hb.hb_aum, ROUND(hb.hb_users * 100.0 / a.total_users, 2) AS pct_users, ROUND(hb.hb_aum * 100.0 / a.total_aum, 2) AS pct_aum FROM high_balance hb CROSS JOIN all_users a ``` |
| **Gold Result (summary)** | 1 row: counts + % of users + % of AUM. Plus demographics query |
| **Expected Row Count** | 1 + top 10 demographic segments |

---

## Q036

| Field | Value |
|-------|-------|
| **ID** | Q036 |
| **Question (NL)** | cuoi tuan user co rut tien nhieu hon ngay thuong khong? |
| **Category** | Date/Time |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | GRASS_DATE, cashout sub-channels |
| **Business Rules / Notes** | Cần phân loại ngày thành weekday vs weekend (EXTRACT(DAYOFWEEK)). Tính AVG daily cashout cho mỗi nhóm. Cashout = full 7 sub-channels. Known insight: Mar 7-8 (Sat-Sun) có spike +38-46%. LLM trap: (1) BQ DAYOFWEEK: 1=Sunday, 7=Saturday — dễ code sai, (2) thiếu sub-channels. |
| **Gold SQL** | ```sql SELECT CASE WHEN EXTRACT(DAYOFWEEK FROM GRASS_DATE) IN (1, 7) THEN 'Weekend' ELSE 'Weekday' END AS day_type, COUNT(DISTINCT GRASS_DATE) AS num_days, SUM(COALESCE(cashout_gmv,0)+COALESCE(cashout_napas_gmv,0)+COALESCE(cashout_p2p_gmv,0)+COALESCE(cashout_payment_gmv,0)+COALESCE(cashout_stock_gmv,0)+COALESCE(cashout_mp_gmv,0)+COALESCE(cashout_payment_mp_gmv,0)) AS total_cashout, ROUND(SUM(COALESCE(cashout_gmv,0)+COALESCE(cashout_napas_gmv,0)+COALESCE(cashout_p2p_gmv,0)+COALESCE(cashout_payment_gmv,0)+COALESCE(cashout_stock_gmv,0)+COALESCE(cashout_mp_gmv,0)+COALESCE(cashout_payment_mp_gmv,0)) / COUNT(DISTINCT GRASS_DATE), 0) AS avg_daily_cashout FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' GROUP BY CASE WHEN EXTRACT(DAYOFWEEK FROM GRASS_DATE) IN (1, 7) THEN 'Weekend' ELSE 'Weekday' END ``` |
| **Gold Result (summary)** | 2 rows: Weekend vs Weekday avg daily cashout |
| **Expected Row Count** | 2 |

---

## Q037

| Field | Value |
|-------|-------|
| **ID** | Q037 |
| **Question (NL)** | user ttt duoc nhan lai bao nhieu 1 ngay? phan bo theo nhom so du ra sao? |
| **Category** | Aggregation |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | INTEREST, INT_GROUP, BAL_GROUP, GRASS_DATE |
| **Business Rules / Notes** | "Lãi 1 ngày" = SUM(INTEREST) for 1 specific day. "Phân bổ theo nhóm số dư" = GROUP BY BAL_GROUP hoặc INT_GROUP. LLM trap: (1) Dùng sai column interest_gmv, (2) Không biết INT_GROUP/BAL_GROUP columns tồn tại → cố tự CASE WHEN, (3) SUM across nhiều ngày thay vì 1 ngày. |
| **Gold SQL** | ```sql SELECT BAL_GROUP, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS users, SUM(INTEREST) AS daily_interest, AVG(INTEREST) AS avg_interest_per_user FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE = '2026-01-31' AND INTEREST > 0 GROUP BY BAL_GROUP ORDER BY daily_interest DESC ``` |
| **Gold Result (summary)** | ~6-7 rows (BAL_GROUPs), sorted by interest contribution |
| **Expected Row Count** | 6-7 |

---

## Q038

| Field | Value |
|-------|-------|
| **ID** | Q038 |
| **Question (NL)** | user reactive thang 2 quay lai voi bao nhieu tien? co giu lai duoc khong? |
| **Category** | Subquery |
| **Difficulty** | Complex |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | USER_ID, MAU_TYPE, MFU_TYPE, BALANCE, cashin sub-channels, GRASS_DATE |
| **Business Rules / Notes** | "Reactive" = MAU_TYPE = '3.Reactive' trong tháng 2. "Quay lại với bao nhiêu tiền" = tổng cashin hoặc balance cuối tháng 2 của nhóm reactive. "Giữ lại được không" = cần check tháng 3 xem họ còn MFU không → subquery/JOIN 2 tháng. LLM trap: (1) Không biết MAU_TYPE = '3.Reactive', (2) Chỉ query 1 tháng mà không check retention. |
| **Gold SQL** | ```sql WITH reactive_feb AS ( SELECT DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) AS uid FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' AND MAU_TYPE = '3.Reactive' ), feb_metrics AS ( SELECT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) AS uid, SUM(COALESCE(cashin_gmv,0)+COALESCE(cashin_p2p_gmv,0)+COALESCE(cashin_va_gmv,0)+COALESCE(cashin_ai_gmv,0)+COALESCE(cashin_stock_gmv,0)+COALESCE(cashin_payout_gmv,0)+COALESCE(cashin_mp_gmv,0)) AS total_cashin FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' AND CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) IN (SELECT uid FROM reactive_feb) GROUP BY CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) ), mar_status AS ( SELECT DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) AS uid FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-03-01' AND '2026-03-08' AND MAU_TYPE != '0.Churn' ) SELECT COUNT(DISTINCT f.uid) AS reactive_users, SUM(f.total_cashin) AS total_reactive_cashin, AVG(f.total_cashin) AS avg_cashin_per_user, COUNT(DISTINCT m.uid) AS retained_in_mar, ROUND(COUNT(DISTINCT m.uid) * 100.0 / NULLIF(COUNT(DISTINCT f.uid), 0), 2) AS retention_pct FROM feb_metrics f LEFT JOIN mar_status m ON f.uid = m.uid ``` |
| **Gold Result (summary)** | 1 row: reactive count + cashin + retention into March |
| **Expected Row Count** | 1 |

---

## Q039

| Field | Value |
|-------|-------|
| **ID** | Q039 |
| **Question (NL)** | user nap qua p2p vs nap thuong, nhom nao nhieu hon? |
| **Category** | Conditional Logic |
| **Difficulty** | Simple |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | CASHIN_GMV, CASHIN_P2P_GMV, USER_ID, GRASS_DATE |
| **Business Rules / Notes** | "Nạp qua P2P" = cashin_p2p_gmv. "Nạp thường" = cashin_gmv (cashin thuần từ ví MoMo). So sánh 2 channels. Câu đơn giản nhưng LLM có thể: (1) Gộp tất cả sub-channels thay vì chỉ 2, (2) Hiểu "nạp thường" sai (nghĩ là total). Không nói timeframe. |
| **Gold SQL** | ```sql SELECT 'Cashin Thuần' AS channel, COUNT(DISTINCT CASE WHEN CASHIN_TRANS > 0 THEN CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) END) AS users, SUM(COALESCE(CASHIN_GMV, 0)) AS gmv FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' UNION ALL SELECT 'Cashin P2P', COUNT(DISTINCT CASE WHEN CASHIN_P2P_TRANS > 0 THEN CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) END), SUM(COALESCE(CASHIN_P2P_GMV, 0)) FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' ``` |
| **Gold Result (summary)** | 2 rows: P2P vs Thuần — user count + GMV comparison |
| **Expected Row Count** | 2 |

---

## Q040

| Field | Value |
|-------|-------|
| **ID** | Q040 |
| **Question (NL)** | nguoi dung tui+ duoc quyen loi gi? bao nhieu nguoi su dung tung quyen loi? |
| **Category** | Multi-step |
| **Difficulty** | Complex |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | PLUS_TYPE, IS_STOCKBACK, IS_WHEEL, IS_TKOL8M, IS_CASHBACK, IS_CASHOUT_NAPAS, TOTAL_CASHBACK_GMV, CASHOUT_NAPAS_GMV, USER_ID, GRASS_DATE |
| **Business Rules / Notes** | Quyền lợi Túi+ gồm: (1) Cashback 0.1% thanh toán (IS_CASHBACK), (2) Rút napas miễn phí 100tr/tháng (IS_CASHOUT_NAPAS), (3) Stockback cổ phiếu (IS_STOCKBACK), (4) Vòng quay (IS_WHEEL), (5) TKOL 8M ưu đãi (IS_TKOL8M). Cần COUNT DISTINCT users cho mỗi benefit. Filter Túi+ users trước. LLM gần chắc không biết 5 campaign behavior tags này tồn tại — đây là trap rất khó. |
| **Gold SQL** | ```sql SELECT COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS total_tui_plus, COUNT(DISTINCT CASE WHEN IS_CASHBACK = 'Cashback' THEN CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) END) AS used_cashback, COUNT(DISTINCT CASE WHEN IS_CASHOUT_NAPAS = 'Cashout' THEN CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) END) AS used_napas, COUNT(DISTINCT CASE WHEN IS_STOCKBACK = 'Claim Stockback' THEN CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) END) AS used_stockback, COUNT(DISTINCT CASE WHEN IS_WHEEL = 'Wheel88' THEN CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) END) AS used_wheel, COUNT(DISTINCT CASE WHEN IS_TKOL8M = 'TKOL 8M' THEN CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) END) AS used_tkol8m FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-01-01' AND '2026-01-31' AND PLUS_TYPE NOT IN ('0.Churn', 'None') AND PLUS_TYPE IS NOT NULL ``` |
| **Gold Result (summary)** | 1 row: total Túi+ users + count per benefit type |
| **Expected Row Count** | 1 |

---

## Summary Tables

### Batch 2 Difficulty Distribution

| Difficulty | Count | IDs |
|------------|-------|-----|
| Simple | 4 | Q026, Q028, Q034, Q039 |
| Moderate | 7 | Q023, Q027, Q030, Q032, Q033, Q036, Q037 |
| Complex | 5 | Q021, Q024, Q035, Q038, Q040 |
| Ambiguous | 4 | Q022, Q025, Q029, Q031 |

### Batch 2 Category Distribution

| Category | Count | IDs |
|----------|-------|-----|
| Aggregation | 5 | Q023, Q026, Q032, Q033, Q034 |
| Ranking + Filter | 1 | Q028 |
| Window + Complex | 1 | Q021 |
| Date/Time | 2 | Q027, Q036 |
| Conditional Logic | 3 | Q030, Q035, Q039 |
| Multi-step | 2 | Q024, Q040 |
| Subquery | 1 | Q038 |
| Ambiguous | 4 | Q022, Q025, Q029, Q031 |

### Batch 2 — LLM Trap Types (NEW traps not in Batch 1)

| Trap Type | Questions | Why LLMs Fail |
|-----------|-----------|---------------|
| **Causal "tại sao" questions** | Q022, Q029 | SQL không trả lời "tại sao" — cần decompose thành "cái gì thay đổi" |
| **Behavioral journey questions** | Q021, Q025 | Cần window functions/self-join phức tạp, hoặc event tracking table |
| **TRANS columns (not just GMV)** | Q023, Q024, Q034 | LLM chỉ biết GMV columns, ít khi biết TRANS columns tồn tại |
| **Campaign behavior tags** | Q033, Q040 | IS_CASHBACK, IS_STOCKBACK, IS_WHEEL, IS_TKOL8M, IS_CASHOUT_NAPAS — hidden columns |
| **BAL_GROUP/INT_GROUP tiers** | Q032, Q037 | LLM tự viết CASE WHEN thay vì dùng column sẵn có |
| **Weekend vs weekday logic** | Q036 | BQ DAYOFWEEK quirks (1=Sunday) |
| **Relative date ("30 ngày qua")** | Q024, Q027, Q029 | Cần DATE_SUB(CURRENT_DATE()) thay vì hardcode |
| **Retention cross-month** | Q038 | Cần JOIN 2 tháng, check if user still active |
| **Money Pool specifics** | Q024, Q025 | IS_MP column + Money Pool-specific columns |

---
---

# BATCH 3: Tier/Segment + TTT as Source of Fund (Q041–Q050)

> Batch này focus vào: (1) Tier system mới (Silver/Gold/Platinum từ 01/2026), (2) TTT dùng làm nguồn thanh toán/chuyển tiền (SOF penetration), (3) Các columns mới: ttt_p2p_gmv, ttt_payment_gmv, momo_p2p_gmv, momo_payment_gmv, tier, plus_segment, is_buy_package, is_coin_int...

---

## Q041

| Field | Value |
|-------|-------|
| **ID** | Q041 |
| **Question (NL)** | tui+ bac vang kim cuong moi hang co bao nhieu nguoi? |
| **Category** | Aggregation |
| **Difficulty** | Simple |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | TIER, USER_ID, GRASS_DATE, PLUS_TYPE |
| **Business Rules / Notes** | "Bạc vàng kim cương" = Silver, Gold, Platinum (column TIER). Cần filter PLUS_TYPE NOT IN ('0.Churn', 'None') trước, rồi GROUP BY TIER. REGEXP_EXTRACT cho dedup. Column TIER mới từ 01/2026 — LLM gần chắc không biết column này tồn tại, sẽ cố dùng PLUS_SEGMENT hoặc CASE WHEN từ BALANCE. Không nói tháng nào. |
| **Gold SQL** | ```sql SELECT TIER, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS users FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' AND PLUS_TYPE NOT IN ('0.Churn', 'None') AND PLUS_TYPE IS NOT NULL GROUP BY TIER ORDER BY users DESC ``` |
| **Gold Result (summary)** | 3 rows: Silver, Gold, Platinum user counts |
| **Expected Row Count** | 3 |

---

## Q042

| Field | Value |
|-------|-------|
| **ID** | Q042 |
| **Question (NL)** | bao nhieu nguoi bo tien mua tui+? ho chi bao nhieu? |
| **Category** | Aggregation |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | PLUS_SEGMENT, IS_BUY_PACKAGE, PACKAGE_GMV, PACKAGE_TRANS, USER_ID, GRASS_DATE |
| **Business Rules / Notes** | "Bỏ tiền mua" = 2 khía cạnh: (1) mua subscription Túi+ (PLUS_SEGMENT chứa '+ Buy' suffix — Silver + Buy = 9K, Gold + Buy = 19K, Platinum + Buy = 49K), (2) mua gói bundle voucher (IS_BUY_PACKAGE). Câu hỏi ambiguous — user hỏi về subscription hay bundle? Agent tốt nên trả cả 2. LLM sẽ fail vì: (1) không biết PLUS_SEGMENT format mới, (2) không biết IS_BUY_PACKAGE, PACKAGE_GMV columns tồn tại. |
| **Gold SQL** | ```sql -- Part 1: Subscription Túi+ (trả tiền mua tier) SELECT PLUS_SEGMENT, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS users FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' AND PLUS_SEGMENT LIKE '%Buy%' GROUP BY PLUS_SEGMENT ORDER BY users DESC; -- Part 2: Bundle voucher SELECT COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS bundle_buyers, SUM(COALESCE(PACKAGE_GMV, 0)) AS total_package_revenue, SUM(COALESCE(PACKAGE_TRANS, 0)) AS total_package_trans FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' AND IS_BUY_PACKAGE IS NOT NULL AND IS_BUY_PACKAGE != 'None' ``` |
| **Gold Result (summary)** | Part 1: rows per Buy segment. Part 2: total buyers + revenue |
| **Expected Row Count** | Multi-query |

---

## Q043

| Field | Value |
|-------|-------|
| **ID** | Q043 |
| **Question (NL)** | user ttt dung tien ttt de thanh toan va chuyen tien chiem bao nhieu % tong momo? |
| **Category** | Aggregation |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | TTT_P2P_GMV, TTT_PAYMENT_GMV, MOMO_P2P_GMV, MOMO_PAYMENT_GMV, GRASS_DATE |
| **Business Rules / Notes** | % penetration = ttt_gmv / momo_gmv * 100. Có 2 metrics: P2P penetration (ttt_p2p_gmv / momo_p2p_gmv) và Payment penetration (ttt_payment_gmv / momo_payment_gmv). Columns mới hoàn toàn — LLM không biết tồn tại. Sẽ cố dùng cashout_p2p_gmv hoặc cashout_payment_gmv (sai vì đó chỉ là cashout, không phải cross-platform metric). |
| **Gold SQL** | ```sql SELECT SUM(COALESCE(TTT_P2P_GMV, 0)) AS ttt_p2p, SUM(COALESCE(MOMO_P2P_GMV, 0)) AS momo_p2p, ROUND(SUM(COALESCE(TTT_P2P_GMV, 0)) * 100.0 / NULLIF(SUM(COALESCE(MOMO_P2P_GMV, 0)), 0), 2) AS p2p_penetration_pct, SUM(COALESCE(TTT_PAYMENT_GMV, 0)) AS ttt_payment, SUM(COALESCE(MOMO_PAYMENT_GMV, 0)) AS momo_payment, ROUND(SUM(COALESCE(TTT_PAYMENT_GMV, 0)) * 100.0 / NULLIF(SUM(COALESCE(MOMO_PAYMENT_GMV, 0)), 0), 2) AS payment_penetration_pct FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' ``` |
| **Gold Result (summary)** | 1 row: P2P penetration % + Payment penetration % |
| **Expected Row Count** | 1 |

---

## Q044

| Field | Value |
|-------|-------|
| **ID** | Q044 |
| **Question (NL)** | tier platinum co so du trung binh bao nhieu? so voi silver va gold? |
| **Category** | Aggregation |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | TIER, BALANCE, AVG_BALANCE, USER_ID, GRASS_DATE, PLUS_TYPE |
| **Business Rules / Notes** | GROUP BY TIER, tính AVG(BALANCE) tại end-of-month snapshot. Filter PLUS_TYPE active. Bẫy: (1) TIER column mới, LLM không biết, (2) Dùng AVG_BALANCE (rolling 30d) thay vì AVG(BALANCE) (snapshot) — 2 con số khác nhau, câu hỏi hỏi "số dư trung bình" có thể map vào cả 2. (3) Platinum = Balance 50M+ nên avg balance phải rất cao. |
| **Gold SQL** | ```sql SELECT TIER, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS users, AVG(BALANCE) AS avg_balance, SUM(BALANCE) AS total_aum FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE = '2026-02-28' AND PLUS_TYPE NOT IN ('0.Churn', 'None') AND PLUS_TYPE IS NOT NULL GROUP BY TIER ORDER BY avg_balance DESC ``` |
| **Gold Result (summary)** | 3 rows: Platinum (avg very high ~50M+), Gold, Silver — sorted by avg_balance |
| **Expected Row Count** | 3 |

---

## Q045

| Field | Value |
|-------|-------|
| **ID** | Q045 |
| **Question (NL)** | user nhan xu sinh loi co bao nhieu? ho co xu huong giu tien lau hon khong? |
| **Category** | Multi-step |
| **Difficulty** | Complex |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | IS_COIN_INT, IS_COIN_SPENT, USER_ID, BALANCE, MFU_TYPE, GRASS_DATE |
| **Business Rules / Notes** | "Xu sinh lời" = IS_COIN_INT column (scheme collab MoMo Xu, 8%/năm). "Giữ tiền lâu hơn" = so sánh MFU retention hoặc avg balance giữa nhóm IS_COIN_INT active vs non-active. Cần 2 queries: (1) count IS_COIN_INT users, (2) compare balance/retention metrics. LLM gần chắc không biết IS_COIN_INT tồn tại. Câu hỏi cũng liên quan IS_COIN_SPENT (đổi xu → voucher). |
| **Gold SQL** | ```sql -- Part 1: Count coin interest users SELECT IS_COIN_INT, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS users, AVG(BALANCE) AS avg_balance FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE = '2026-02-28' AND MFU_TYPE != '0.Churn' GROUP BY IS_COIN_INT; -- Part 2: Compare retention (MFU retain rate) SELECT CASE WHEN IS_COIN_INT IS NOT NULL AND IS_COIN_INT != 'None' THEN 'Coin Interest User' ELSE 'Regular User' END AS segment, COUNT(DISTINCT CASE WHEN MFU_TYPE = '2.Retain' THEN CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) END) AS retained, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS total, ROUND(COUNT(DISTINCT CASE WHEN MFU_TYPE = '2.Retain' THEN CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING) END) * 100.0 / NULLIF(COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)), 0), 2) AS retain_pct FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' AND MFU_TYPE != '0.Churn' GROUP BY CASE WHEN IS_COIN_INT IS NOT NULL AND IS_COIN_INT != 'None' THEN 'Coin Interest User' ELSE 'Regular User' END ``` |
| **Gold Result (summary)** | Part 1: user counts + avg balance by IS_COIN_INT. Part 2: retention comparison |
| **Expected Row Count** | Multi-query |

---

## Q046

| Field | Value |
|-------|-------|
| **ID** | Q046 |
| **Question (NL)** | % nguoi dung ttt dung tien ttt chuyen khoan tang hay giam? tach p2p voi thanh toan |
| **Category** | Date/Time |
| **Difficulty** | Complex |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | TTT_P2P_GMV, TTT_PAYMENT_GMV, MOMO_P2P_GMV, MOMO_PAYMENT_GMV, GRASS_DATE |
| **Business Rules / Notes** | Cần tính penetration % theo tháng cho cả P2P và Payment, rồi so trend MoM. Penetration = ttt_gmv / momo_gmv. "Tách P2P với thanh toán" = 2 metrics riêng. Cần ít nhất 2-3 tháng data. LLM sẽ fail vì: (1) Không biết columns mới, (2) Dùng cashout_p2p thay vì ttt_p2p_gmv, (3) Không có mẫu số momo_* để tính %. |
| **Gold SQL** | ```sql SELECT DATE_TRUNC(GRASS_DATE, MONTH) AS month, ROUND(SUM(COALESCE(TTT_P2P_GMV, 0)) * 100.0 / NULLIF(SUM(COALESCE(MOMO_P2P_GMV, 0)), 0), 2) AS p2p_penetration_pct, ROUND(SUM(COALESCE(TTT_PAYMENT_GMV, 0)) * 100.0 / NULLIF(SUM(COALESCE(MOMO_PAYMENT_GMV, 0)), 0), 2) AS payment_penetration_pct FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2025-12-01' AND '2026-02-28' GROUP BY DATE_TRUNC(GRASS_DATE, MONTH) ORDER BY month ``` |
| **Gold Result (summary)** | 3 rows (Dec, Jan, Feb): P2P penetration % + Payment penetration % monthly trend |
| **Expected Row Count** | 3 |

---

## Q047

| Field | Value |
|-------|-------|
| **ID** | Q047 |
| **Question (NL)** | merchant nap tien payout vao ttt tu khi nao? co bao nhieu merchant dang dung? |
| **Category** | Aggregation |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | FIRST_PAYOUT_DATE, CASHIN_PAYOUT_GMV, CASHIN_PAYOUT_TRANS, USER_ID, GRASS_DATE |
| **Business Rules / Notes** | "Merchant nạp payout" = user có FIRST_PAYOUT_DATE IS NOT NULL hoặc CASHIN_PAYOUT_GMV > 0. "Từ khi nào" = MIN(FIRST_PAYOUT_DATE). "Bao nhiêu merchant" = COUNT DISTINCT users có payout. Column FIRST_PAYOUT_DATE mới — LLM không biết. Sẽ cố filter bằng cashin_payout_gmv > 0 (gần đúng nhưng thiếu FIRST_PAYOUT_DATE insight). |
| **Gold SQL** | ```sql SELECT COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS active_merchants, MIN(FIRST_PAYOUT_DATE) AS earliest_payout_date, SUM(COALESCE(CASHIN_PAYOUT_GMV, 0)) AS total_payout_gmv, SUM(COALESCE(CASHIN_PAYOUT_TRANS, 0)) AS total_payout_trans FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' AND FIRST_PAYOUT_DATE IS NOT NULL ``` |
| **Gold Result (summary)** | 1 row: merchant count + earliest payout date + GMV + trans |
| **Expected Row Count** | 1 |

---

## Q048

| Field | Value |
|-------|-------|
| **ID** | Q048 |
| **Question (NL)** | tier nao dung ttt de thanh toan nhieu nhat? platinum co dung nhieu hon silver khong? |
| **Category** | Conditional Logic |
| **Difficulty** | Complex |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | TIER, TTT_PAYMENT_GMV, TTT_PAYMENT_TRANS, TTT_P2P_GMV, USER_ID, PLUS_TYPE, GRASS_DATE |
| **Business Rules / Notes** | Cross 2 dimensions mới: TIER × TTT as SOF. Cần GROUP BY TIER, SUM(ttt_payment_gmv + ttt_p2p_gmv). Filter PLUS_TYPE active. LLM fail vì: (1) TIER column unknown, (2) TTT_PAYMENT_GMV unknown → dùng cashout_payment_gmv (gần nhưng không phải SOF metric), (3) Thiếu cross-analysis tier × SOF. |
| **Gold SQL** | ```sql SELECT TIER, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS users, SUM(COALESCE(TTT_PAYMENT_GMV, 0)) AS ttt_payment_gmv, SUM(COALESCE(TTT_P2P_GMV, 0)) AS ttt_p2p_gmv, SUM(COALESCE(TTT_PAYMENT_GMV, 0) + COALESCE(TTT_P2P_GMV, 0)) AS total_sof_gmv, ROUND(SUM(COALESCE(TTT_PAYMENT_GMV, 0) + COALESCE(TTT_P2P_GMV, 0)) / NULLIF(COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)), 0), 0) AS avg_sof_per_user FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' AND PLUS_TYPE NOT IN ('0.Churn', 'None') AND PLUS_TYPE IS NOT NULL GROUP BY TIER ORDER BY total_sof_gmv DESC ``` |
| **Gold Result (summary)** | 3 rows: tier comparison on SOF usage, Platinum likely highest per user |
| **Expected Row Count** | 3 |

---

## Q049

| Field | Value |
|-------|-------|
| **ID** | Q049 |
| **Question (NL)** | user chuyen tien qua ngan hang (e2b) tu ttt so voi toan momo nhu nao? |
| **Category** | Aggregation |
| **Difficulty** | Moderate |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | TTT_P2P_E2B_GMV, TTT_P2P_E2B_TRANS, MOMO_P2P_E2B_GMV, MOMO_P2P_E2B_TRANS, GRASS_DATE |
| **Business Rules / Notes** | E2B = E-wallet to Bank transfer. Columns rất mới (chưa có đầy đủ data model note). So sánh TTT E2B vs MoMo E2B để tính penetration. LLM gần chắc không biết E2B columns tồn tại — sẽ cố dùng cashout_napas (liên quan nhưng khác concept: napas = TTT → bank trực tiếp, E2B = ví → bank qua P2P). |
| **Gold SQL** | ```sql SELECT SUM(COALESCE(TTT_P2P_E2B_GMV, 0)) AS ttt_e2b_gmv, SUM(COALESCE(MOMO_P2P_E2B_GMV, 0)) AS momo_e2b_gmv, ROUND(SUM(COALESCE(TTT_P2P_E2B_GMV, 0)) * 100.0 / NULLIF(SUM(COALESCE(MOMO_P2P_E2B_GMV, 0)), 0), 2) AS e2b_penetration_pct, SUM(COALESCE(TTT_P2P_E2B_TRANS, 0)) AS ttt_e2b_trans, SUM(COALESCE(MOMO_P2P_E2B_TRANS, 0)) AS momo_e2b_trans FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' ``` |
| **Gold Result (summary)** | 1 row: TTT E2B GMV, MoMo E2B GMV, penetration % |
| **Expected Row Count** | 1 |

---

## Q050

| Field | Value |
|-------|-------|
| **ID** | Q050 |
| **Question (NL)** | so sanh hanh vi su dung ttt lam nguon tien cua 3 tier bac vang kim cuong — ai chuyen tien nhieu, ai thanh toan nhieu? |
| **Category** | Multi-step |
| **Difficulty** | Complex |
| **Target Tables** | mart_ttt_daily_user_record |
| **Target Columns** | TIER, TTT_P2P_GMV, TTT_P2P_TRANS, TTT_PAYMENT_GMV, TTT_PAYMENT_TRANS, TTT_P2P_E2B_GMV, MOMO_P2P_GMV, MOMO_PAYMENT_GMV, USER_ID, PLUS_TYPE, GRASS_DATE |
| **Business Rules / Notes** | Full cross-analysis: TIER × (P2P + Payment + E2B). Cần per-user metrics (avg GMV/user) để so sánh fair vì Platinum ít user hơn nhưng chi nhiều hơn. Also tính penetration per tier = ttt_gmv / momo_gmv. Đây là câu hỏi tổng hợp exploit gần như tất cả columns mới: TIER + ttt_p2p + ttt_payment + momo_p2p + momo_payment + e2b. LLM sẽ fail ở hầu hết mọi khía cạnh. |
| **Gold SQL** | ```sql SELECT TIER, COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)) AS users, -- P2P SUM(COALESCE(TTT_P2P_GMV, 0)) AS ttt_p2p_gmv, ROUND(SUM(COALESCE(TTT_P2P_GMV, 0)) / NULLIF(COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)), 0), 0) AS avg_p2p_per_user, ROUND(SUM(COALESCE(TTT_P2P_GMV, 0)) * 100.0 / NULLIF(SUM(COALESCE(MOMO_P2P_GMV, 0)), 0), 2) AS p2p_penetration_pct, -- Payment SUM(COALESCE(TTT_PAYMENT_GMV, 0)) AS ttt_payment_gmv, ROUND(SUM(COALESCE(TTT_PAYMENT_GMV, 0)) / NULLIF(COUNT(DISTINCT CAST(REGEXP_EXTRACT(USER_ID, r'\d+') AS STRING)), 0), 0) AS avg_payment_per_user, ROUND(SUM(COALESCE(TTT_PAYMENT_GMV, 0)) * 100.0 / NULLIF(SUM(COALESCE(MOMO_PAYMENT_GMV, 0)), 0), 2) AS payment_penetration_pct, -- E2B SUM(COALESCE(TTT_P2P_E2B_GMV, 0)) AS ttt_e2b_gmv FROM `momovn-prod.BU_FI.mart_ttt_daily_user_record` WHERE GRASS_DATE BETWEEN '2026-02-01' AND '2026-02-28' AND PLUS_TYPE NOT IN ('0.Churn', 'None') AND PLUS_TYPE IS NOT NULL GROUP BY TIER ORDER BY ttt_p2p_gmv + ttt_payment_gmv DESC ``` |
| **Gold Result (summary)** | 3 rows: Silver, Gold, Platinum — full SOF breakdown with per-user avg + penetration % |
| **Expected Row Count** | 3 |

---

## Batch 3 Summary

### Batch 3 Difficulty Distribution

| Difficulty | Count | IDs |
|------------|-------|-----|
| Simple | 1 | Q041 |
| Moderate | 4 | Q042, Q043, Q044, Q047, Q049 |
| Complex | 4 | Q045, Q046, Q048, Q050 |
| Ambiguous | 0 | — |

### Batch 3 Category Distribution

| Category | Count | IDs |
|----------|-------|-----|
| Aggregation | 5 | Q041, Q042, Q043, Q047, Q049 |
| Date/Time | 1 | Q046 |
| Conditional Logic | 1 | Q048 |
| Multi-step | 2 | Q045, Q050 |

### Batch 3 — LLM Trap Types (NEW traps)

| Trap Type | Questions | Why LLMs Fail |
|-----------|-----------|---------------|
| **TIER column unknown** | Q041, Q044, Q048, Q050 | Column mới từ 01/2026, LLM chưa biết |
| **TTT SOF columns (ttt_p2p_gmv, ttt_payment_gmv)** | Q043, Q046, Q048, Q050 | Columns mới hoàn toàn, LLM dùng cashout_p2p thay thế (sai) |
| **MOMO cross-platform columns** | Q043, Q046, Q049, Q050 | momo_p2p_gmv, momo_payment_gmv — mẫu số penetration, LLM không biết |
| **E2B (E-wallet to Bank) columns** | Q049, Q050 | Rất mới, LLM nhầm với napas |
| **PLUS_SEGMENT + Buy suffix** | Q042 | Format mới, LLM chỉ biết segments cũ |
| **IS_BUY_PACKAGE / PACKAGE_GMV** | Q042 | Columns mới cho bundle voucher revenue |
| **IS_COIN_INT / IS_COIN_SPENT** | Q045 | MoMo Xu collab scheme, LLM không biết |
| **FIRST_PAYOUT_DATE** | Q047 | Merchant-specific column, rất niche |

---

## Summary Tables (Combined Batch 1 + 2 + 3)

### Full Difficulty Distribution (50 questions)

| Difficulty | Count | IDs |
|------------|-------|-----|
| Simple | 8 | Q001, Q012, Q017, Q026, Q028, Q034, Q039, Q041 |
| Moderate | 19 | Q003, Q006, Q008, Q009, Q010, Q011, Q019, Q023, Q027, Q030, Q032, Q033, Q036, Q037, Q042, Q043, Q044, Q047, Q049 |
| Complex | 16 | Q007, Q013, Q014, Q015, Q016, Q018, Q021, Q024, Q035, Q038, Q040, Q045, Q046, Q048, Q050 |
| Ambiguous | 7 | Q002, Q004, Q005, Q020, Q022, Q025, Q029, Q031 |

### Full Category Distribution (50 questions)

| Category | Count | IDs |
|----------|-------|-----|
| Aggregation | 15 | Q001, Q003, Q008, Q012, Q017, Q023, Q026, Q032, Q033, Q034, Q041, Q042, Q043, Q047, Q049 |
| Ranking + Filter | 3 | Q006, Q019, Q028 |
| Window + Complex | 2 | Q013, Q021 |
| Date/Time | 6 | Q011, Q015, Q018, Q027, Q036, Q046 |
| Conditional Logic | 5 | Q009, Q030, Q035, Q039, Q048 |
| Multi-step | 7 | Q005, Q007, Q014, Q024, Q040, Q045, Q050 |
| Subquery | 2 | Q016, Q038 |
| Ambiguous | 7 | Q002, Q004, Q020, Q022, Q025, Q029, Q031 |

### Difficulty Distribution

| Difficulty | Count | IDs |
|------------|-------|-----|
| Simple | 3 | Q001, Q012, Q017 |
| Moderate | 7 | Q003, Q006, Q008, Q009, Q010, Q011, Q019 |
| Complex | 7 | Q007, Q013, Q014, Q015, Q016, Q018, Q019 |
| Ambiguous | 3 | Q002, Q005, Q020 |

### Category Distribution

| Category | Count | IDs |
|----------|-------|-----|
| Aggregation | 5 | Q001, Q003, Q008, Q012, Q017 |
| Ranking + Filter | 2 | Q006, Q019 |
| Window + Complex | 1 | Q013 |
| Date/Time | 3 | Q011, Q015, Q018 |
| Conditional Logic | 1 | Q009 |
| Multi-step | 3 | Q005, Q007, Q014 |
| Subquery | 1 | Q016 |
| Ambiguous | 3 | Q002, Q005, Q020 |

### Primary LLM Trap Coverage

| Trap Type | Questions Hit | Why LLMs Fail |
|-----------|--------------|---------------|
| AUM snapshot vs SUM(all days) | Q001, Q008, Q012, Q015, Q018 | LLM default là SUM across range → inflate 30x |
| REGEXP_EXTRACT dedup | Q002, Q006, Q009, Q011, Q014, Q016, Q017, Q019 | LLM không biết mp_ prefix tồn tại |
| Cashin/Cashout sub-channels | Q003, Q007, Q010, Q013, Q019 | LLM chỉ dùng column gốc, miss ~50% |
| MAU vs MFU confusion | Q002, Q005 | Cả 2 đều là "active users" nhưng definition khác nhau |
| Column name sai | Q004 | interest_gmv không tồn tại, đúng là interest |
| PLUS_TYPE filter logic | Q009 | Phải exclude '0.Churn' VÀ 'None' |
| DATE_TRUNC vs GRASS_MONTH | Q011 | GRASS_MONTH không tồn tại trong schema |
| Relative date inference | Q002, Q003, Q005, Q015, Q020 | "Tháng rồi", "năm ngoái cùng kỳ" → LLM phải infer |
| Vague decomposition | Q005, Q020 | Câu hỏi cần multiple metrics, LLM trả 1 |
| Mixed date logic in 1 query | Q012, Q018 | AUM = snapshot, MAU = range — 2 logic trong 1 câu |
