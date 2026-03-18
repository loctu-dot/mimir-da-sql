# Apollo Sampling Validation — Mô hình SQL & Quy tắc An toàn

Tài liệu này chứa mã SQL cụ thể triển khai khung kiểm định được mô tả trong `apollo_sampling_validation_framework.md`. Phần 9 cung cấp định nghĩa các bảng. Phần 10 cung cấp các quy tắc cứng bắt buộc khi viết SQL trong pipeline này.

## Phần 9 — Mô hình dữ liệu SQL

### 9.1 Bảng Path Prefix (Toàn bộ dữ liệu — FULL)

Bung mảng step của mỗi session thành tất cả các prefix path, sau đó đếm distinct user cho mỗi path mỗi ngày.

**Đầu vào:** `apollo_path_full_validate_platform` (cấp session, mỗi dòng = 1 user-session với các cột `s1_app` đến `s9_event`)
**Đầu ra:** `apollo_path_count_validate_full`

> **Note — Tại sao cần bảng này?** Đây là bảng cơ sở cho mọi so sánh. Mỗi dòng = 1 prefix path + ngày + số user. Từ bảng này ta biết "path X có bao nhiêu user trong ngày Y" cho toàn bộ quần thể.

```sql
CREATE OR REPLACE TABLE `apollo_path_count_validate_full` AS
WITH base AS (
  -- Gom các cột step thành 1 mảng để xử lý đồng nhất
  SELECT
    event_date,
    user_id,
    device_os,
    [s1_app, s2_app, s3_screen, s4_screen, s5_screen,
     s6_app, s7_app, s8_screen, s9_event] AS step_array
  FROM `apollo_path_full_validate_platform`
),
exploded AS (
  -- Bung mảng thành các prefix: offset=1 → prefix 1 bước, offset=2 → 2 bước, ...
  SELECT
    event_date,
    user_id,
    device_os,
    offset + 1 AS step_level,                                    -- bước thứ mấy
    ARRAY_TO_STRING(ARRAY_SLICE(step_array, 0, offset), ' - ') AS action_key  -- chuỗi prefix
  FROM base,
  UNNEST(step_array) WITH OFFSET offset
)
SELECT
  event_date,
  step_level,
  action_key,
  COUNT(DISTINCT user_id) AS total_users,                                        -- tổng user
  COUNT(DISTINCT IF(LOWER(device_os) = 'ios', user_id, NULL)) AS users_ios,      -- user iOS
  COUNT(DISTINCT IF(LOWER(device_os) != 'ios', user_id, NULL)) AS users_android  -- user Android
FROM exploded
GROUP BY 1, 2, 3;
```

### 9.2 Bảng Path Prefix (Dữ liệu mẫu — SAMPLE)

Cùng logic như 9.1, nhưng chỉ lọc user nằm trong mẫu 10%.

**Đầu vào:** `apollo_path_sample_validate_platform`
**Đầu ra:** `apollo_path_count_validate_sample`

> **Note:** Bảng này cấu trúc giống hệt bảng FULL. Khác biệt duy nhất: source table chỉ chứa 10% user đã được sampling. Khi so sánh với FULL, ta nhân `total_users` × 10 để quy đổi.

```sql
CREATE OR REPLACE TABLE `apollo_path_count_validate_sample` AS
WITH base AS (
  SELECT
    event_date,
    user_id,
    device_os,
    [s1_app, s2_app, s3_screen, s4_screen, s5_screen,
     s6_app, s7_app, s8_screen, s9_event] AS step_array
  FROM `apollo_path_sample_validate_platform`
),
exploded AS (
  SELECT
    event_date,
    user_id,
    device_os,
    offset + 1 AS step_level,
    ARRAY_TO_STRING(ARRAY_SLICE(step_array, 0, offset), ' - ') AS action_key
  FROM base,
  UNNEST(step_array) WITH OFFSET offset
)
SELECT
  event_date,
  step_level,
  action_key,
  COUNT(DISTINCT user_id) AS total_users,
  COUNT(DISTINCT IF(LOWER(device_os) = 'ios', user_id, NULL)) AS users_ios,
  COUNT(DISTINCT IF(LOWER(device_os) != 'ios', user_id, NULL)) AS users_android
FROM exploded
GROUP BY 1, 2, 3;
```

### 9.3 Bảng So sánh Path (Comparison)

Join bảng FULL và SAMPLE. Nhân sample × 10 rồi tính chênh lệch phần trăm.

**Đầu ra:** `agg_apollo_comparison_record`

> **Note — Cách đọc `pct_gap`:** Giá trị dương = sampling ước lượng thừa (overestimate). Giá trị âm = ước lượng thiếu (underestimate). Nếu gap phân bố đều quanh 0 → noise. Nếu lệch hệ thống → bias.

```sql
CREATE OR REPLACE TABLE `agg_apollo_comparison_record` AS
SELECT
  f.event_date,
  f.step_level,
  f.action_key,
  f.total_users                    AS full_users,           -- số user thực tế (full population)
  s.total_users * 10               AS sample_scaled_users,  -- số user mẫu × 10 (quy đổi)
  SAFE_DIVIDE(
    s.total_users * 10 - f.total_users,
    f.total_users
  ) AS pct_gap                                              -- chênh lệch %
FROM `apollo_path_count_validate_full` f
LEFT JOIN `apollo_path_count_validate_sample` s
  USING (event_date, step_level, action_key);
```

### 9.4 Bảng Kiểm định cấp User (User-Level Validation Mart)

Tổng hợp các chỉ số hành vi per-user (session, event, app, độ sâu path) và đánh dấu user nào nằm trong mẫu. Bảng này cho phép so sánh phân bố hành vi giữa sample và full.

**Đầu ra:** `agg_apollo_user_day_mart`

> **Note — Cột `is_in_sample`:** Cột boolean này cho phép lọc nhanh sample vs full bằng `WHERE is_in_sample = TRUE/FALSE` mà không cần join lại.

```sql
CREATE OR REPLACE TABLE `agg_apollo_user_day_mart` AS
WITH user_agg AS (
  SELECT
    event_date,
    user_id,
    COUNT(DISTINCT session_id)        AS total_sessions,    -- số session/ngày
    SUM(ARRAY_LENGTH(all_events))     AS total_events,      -- tổng event/ngày
    COUNT(DISTINCT app)               AS distinct_apps,     -- bao nhiêu miniapp riêng biệt
    AVG(ARRAY_LENGTH(all_apps))       AS avg_path_depth,    -- độ sâu path trung bình
    MAX(ARRAY_LENGTH(all_apps))       AS max_path_depth     -- path dài nhất
  FROM `apollo_session_array_bq_full`,
  UNNEST(all_apps) AS app
  GROUP BY 1, 2
),
sample_user AS (
  SELECT DISTINCT event_date, user_id
  FROM `apollo_session_array_bq_sample`
)
SELECT
  u.*,
  IF(s.user_id IS NOT NULL, TRUE, FALSE) AS is_in_sample   -- đánh dấu user mẫu
FROM user_agg u
LEFT JOIN sample_user s
  USING (event_date, user_id);
```

### 9.5 Kiểm định Điểm bắt đầu (Z-Score theo Miniapp)

Với mỗi miniapp là starting point có ≥ 1.000 user/ngày, tính Z-score nhị thức để kiểm tra liệu tỷ lệ sampling có lệch khỏi kỳ vọng 10% hay không.

**Đầu ra:** `agg_apollo_startpoint_day_mart`

> **Note — Đọc Z-score:** Z ≈ 0 → miniapp này được sampling đúng tỷ lệ. |Z| > 3 → miniapp này có tỷ lệ sampling bất thường (quá nhiều hoặc quá ít user trong mẫu so với kỳ vọng).

```sql
CREATE OR REPLACE TABLE `agg_apollo_startpoint_day_mart` AS
WITH exploded AS (
  SELECT
    event_date,
    user_id,
    is_in_sample,
    app AS miniapp
  FROM `agg_apollo_user_day_mart`,
  UNNEST(potential_start_point) AS app
),
agg AS (
  SELECT
    event_date,
    miniapp,
    COUNT(DISTINCT user_id)                              AS total_users,    -- tổng user full
    COUNT(DISTINCT IF(is_in_sample, user_id, NULL))      AS sample_users   -- user trong mẫu
  FROM exploded
  GROUP BY 1, 2
  HAVING total_users >= 1000    -- chỉ kiểm định miniapp đủ traffic
)
SELECT
  *,
  total_users * 0.1                   AS expected_sample,    -- kỳ vọng = 10% tổng
  SQRT(total_users * 0.1 * 0.9)      AS standard_error,     -- sai số chuẩn nhị thức
  SAFE_DIVIDE(
    sample_users - total_users * 0.1,
    SQRT(total_users * 0.1 * 0.9)
  ) AS z_score                                               -- Z-score
FROM agg;
```

### 9.6 Kiểm định Phân tầng (Theo nhóm Traffic)

Chia miniapp thành 3 nhóm traffic (cao/trung bình/thấp) bằng NTILE(3), rồi tính thống kê Z-score mỗi nhóm. Phát hiện liệu bias có tương quan với mức độ phổ biến của miniapp hay không.

**Đầu ra:** `agg_apollo_startpoint_stratified`

> **Note — Cách đọc:** Nếu `mean_z` ≈ 0 ở cả 3 nhóm → sampling đều tốt. Nếu `mean_z` lệch xa 0 ở một nhóm cụ thể → sampling thiên lệch theo mức traffic đó.

```sql
CREATE OR REPLACE TABLE `agg_apollo_startpoint_stratified` AS
WITH ranked AS (
  SELECT
    *,
    NTILE(3) OVER (PARTITION BY event_date ORDER BY total_users DESC) AS volume_bucket
    -- bucket 1 = traffic cao nhất, bucket 3 = thấp nhất
  FROM `agg_apollo_startpoint_day_mart`
)
SELECT
  event_date,
  volume_bucket,
  COUNT(*)          AS miniapp_count,  -- số miniapp trong nhóm
  AVG(z_score)      AS mean_z,         -- Z-score trung bình
  STDDEV(z_score)   AS std_z           -- độ lệch chuẩn Z-score
FROM ranked
GROUP BY 1, 2;
```

### 9.7 Kiểm định Phân tán (Dispersion Test)

Tính hệ số phân tán φ = Σ(Z²)/(n-1). Nếu φ ≈ 1 → phương sai khớp kỳ vọng nhị thức. Nếu φ > 2 → rất có thể có bias hệ thống.

**Đầu ra:** `agg_apollo_dispersion_day_mart`

> **Note — Trực giác:** Nếu tất cả Z-score đều gần 0 (sampling tốt), thì tổng Z² sẽ xấp xỉ bằng n-1, nên φ ≈ 1. Nếu có vài miniapp bị bias mạnh (Z = 5, 6...), tổng Z² sẽ phình to, kéo φ vượt xa 1.

```sql
CREATE OR REPLACE TABLE `agg_apollo_dispersion_day_mart` AS
WITH z_values AS (
  SELECT event_date, z_score
  FROM `agg_apollo_startpoint_day_mart`
),
agg AS (
  SELECT
    event_date,
    COUNT(*)               AS n,                 -- số miniapp
    AVG(z_score)           AS mean_z,            -- Z trung bình
    STDDEV(z_score)        AS std_z,             -- độ lệch chuẩn Z
    SUM(z_score * z_score) AS chi_square_stat    -- Σ(Z²) = thống kê chi-bình-phương
  FROM z_values
  GROUP BY event_date
)
SELECT
  event_date,
  n,
  mean_z,
  std_z,
  SAFE_DIVIDE(chi_square_stat, n - 1) AS dispersion_phi   -- φ = χ²/df
FROM agg;
```

## Phần 10 — Quy tắc An toàn cho SQL (LLM Guardrails)

Đây là các quy tắc cứng khi viết bất kỳ SQL nào trong pipeline này. Vi phạm sẽ tạo ra kết quả sai.

### Đếm User

**Luôn** dùng `COUNT(DISTINCT user_id)` cho mọi chỉ số cấp user. **Không bao giờ** dùng `COUNT(*)` — nó đếm dòng, không phải user. Một user có nhiều session/event sẽ bị đếm trùng.

> **Note — Ví dụ sai:** `COUNT(*)` trên bảng session sẽ đếm tổng số session, không phải tổng số user. User có 5 session bị đếm 5 lần.

### Sinh Path Prefix

**Luôn** sinh prefix bằng `ARRAY_SLICE(step_array, 0, offset)`. **Không bao giờ** dùng cross join hay tổ hợp — chúng tạo ra các path không tồn tại trong thực tế.

> **Note:** Cross join giữa 2 mảng 10 phần tử tạo 100 dòng thay vì 10 → bùng nổ dữ liệu và kết quả vô nghĩa.

### An toàn UNNEST

**Chỉ một UNNEST cho mỗi dimension trong cùng một query.** Nhiều UNNEST trong cùng mệnh đề FROM (ví dụ: `UNNEST(apps), UNNEST(screens), UNNEST(events)`) tạo tích Descartes — bùng nổ số dòng theo cấp số nhân.

> **Note — Ví dụ:** Mảng apps 10 phần tử × mảng screens 10 phần tử × mảng events 10 phần tử = 1.000 dòng thay vì 10. Kết quả là rác hoàn toàn.

### Mẫu số Sampling

Khi so sánh sample vs full: `expected_sample = population_size × 0.1`. Tỷ lệ sampling luôn là 0.1 (10%).

### Công thức Z-Score

```
Z = (observed - expected) / sqrt(n × p × (1 - p))
```
Trong đó: `n` = tổng quần thể, `p` = 0.1, `observed` = số user trong mẫu.

### Ràng buộc Traffic tối thiểu

**Chỉ kiểm định node/path có ≥ 1.000 user mỗi ngày.** Dưới ngưỡng này, phương sai sampling tự nhiên cao và kết quả không có ý nghĩa thống kê.

> **Note — Tại sao?** Với 10% sampling, path 100 user chỉ có ~10 user trong mẫu. Chênh lệch ±3 user = ±30% gap — hoàn toàn bình thường về mặt thống kê nhưng trông rất "tệ" nếu không hiểu ngữ cảnh.

### Loại bỏ đuôi Traffic thấp

Loại bỏ 5% path có traffic thấp nhất trước khi tính thống kê gap:
```sql
PERCENTILE_CONT(total_users, 0.05)
```

### Quy tắc Trọng số

```
node_weight = node_users / total_users_same_type
weighted_gap = gap_ratio × node_weight
```

Node traffic cao đóng góp tỷ lệ tương xứng vào chỉ số gap cuối cùng.

### An toàn Join

**Luôn** join bảng kiểm định trên `(event_date, step_level, action_key)`. Thiếu bất kỳ key nào sẽ tạo ra kết quả sai do ghép nhầm cross-day hoặc cross-path.

### Công thức Dispersion

```
φ = SUM(Z²) / (n - 1)
```

| Khoảng φ | Diễn giải |
|----------|-----------|
| 0.8 – 1.2 | Tốt — phương sai khớp kỳ vọng nhị thức |
| 1.2 – 1.5 | Phân tán nhẹ — phương sai hơi cao, chấp nhận được |
| > 2.0 | Phân tán nghiêm trọng — cần điều tra bias hệ thống |
