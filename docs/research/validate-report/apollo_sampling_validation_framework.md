# Apollo Path Exploration — Khung Kiểm Định Sampling

## 1. Bối cảnh sản phẩm

### 1.1 Apollo Path Exploration là gì?

Apollo Path Exploration là công cụ phân tích hành trình người dùng của MoMo, lấy cảm hứng từ Path Exploration của GA4 (Google Analytics 4). Công cụ cho phép Product Owner và Data Analyst:

- Truy vết từng bước hành trình người dùng trong ứng dụng MoMo
- Khám phá các chuỗi hành động phổ biến nhất
- Phân tích luồng chuyển đổi giữa các màn hình, miniapp, sự kiện và dịch vụ

Một **path** (hành trình) là một chuỗi có thứ tự các **node** (nút) đại diện cho hành động của người dùng trong một session. Mỗi node thuộc 1 trong 4 loại (gọi là **dimension** — chiều dữ liệu):

| Loại node | Trường nguồn | Ví dụ | Giải thích |
|-----------|-------------|-------|------------|
| miniapp | `app_id` | `vn.momo.platform` | Ứng dụng con bên trong MoMo |
| screen | `screen_name` | `payx payment` | Màn hình hiển thị cho người dùng |
| event | `event_name` | `feature_trans_result` | Sự kiện cụ thể (nhấn nút, hoàn thành giao dịch...) |
| service | `service_name` | `transfer` | Dịch vụ backend xử lý hành động |

> **Note:** Người dùng có thể **chuyển đổi loại node linh hoạt tại mỗi bước** trong path. Ví dụ: `miniapp → miniapp → screen → screen → event → miniapp`. Đây là điểm khác biệt cốt lõi so với GA4 — GA4 chỉ cho phép một loại node cố định cho toàn bộ path.

### 1.2 Logic phân session (Sessionization)

Một **session** nhóm các sự kiện liên tiếp của cùng một người dùng. Session mới bắt đầu khi khoảng cách thời gian giữa 2 sự kiện liên tiếp vượt quá **30 phút**.

> **Note — Tại sao 30 phút?** Đây là quy chuẩn ngành (GA4 cũng dùng 30 phút). Mục đích: nhóm các hành vi có liên quan lại với nhau, đồng thời tách biệt các lượt truy cập độc lập. Nếu người dùng mở MoMo lúc 9h sáng rồi đóng app, mở lại lúc 2h chiều → đó là 2 session hoàn toàn khác nhau.

### 1.3 Logic xây dựng Path

Sau khi phân session, path được xây dựng qua 4 bước:

**Bước 1 — Chuẩn bị dữ liệu event.** Trích xuất raw event với các trường: `event_timestamp`, `user_id`, `device_os`, `app_id`, `screen_name`, `event_name`, `service_name`, `session_id`. Sau đó **forward-fill** các trường bị rỗng trong cùng session — lấy giá trị gần nhất không null từ event trước đó điền vào.

> **Note — Tại sao forward-fill?** Trong thực tế, không phải event nào cũng ghi đủ thông tin. Ví dụ: event "nhấn nút thanh toán" có thể không ghi `screen_name` vì nó kế thừa từ màn hình đang hiển thị. Forward-fill đảm bảo mỗi event đều có đủ 4 dimension để xây path.

**Bước 2 — Gom thành mảng (Path Aggregation).** Nhóm tất cả event trong cùng session thành các mảng có thứ tự — mỗi dimension một mảng riêng:

```sql
groupArray(app_id)        AS all_apps      -- mảng tất cả miniapp theo thứ tự thời gian
groupArray(screen_name)   AS all_screens   -- mảng tất cả screen
groupArray(event_name)    AS all_events    -- mảng tất cả event
groupArray(service_name)  AS all_services  -- mảng tất cả service
```

> **Note:** Mỗi session tạo ra 4 mảng song song cùng độ dài, cùng thứ tự. Vị trí thứ `i` trong `all_apps` tương ứng với vị trí thứ `i` trong `all_screens`, `all_events`, `all_services`.

**Bước 3 — Loại bỏ trùng lặp liên tiếp (Consecutive Dedup).** Thu gọn các giá trị giống nhau liền kề: `A → A → B → C` trở thành `A → B → C`.

> **Note — Tại sao phải dedup?** Miniapp là tầng cha — một miniapp sinh ra rất nhiều event/screen. Nếu không dedup, 5 bước liên tiếp có thể vẫn đang ở cùng một miniapp, trong khi người dùng thực sự muốn xem "miniapp tiếp theo là gì?". Dedup đảm bảo mỗi bước trong path đại diện cho một thay đổi thực sự.

Kỹ thuật dedup dùng tìm kiếm chỉ mục (index-based skipping):
```sql
-- Tìm vị trí đầu tiên trong mảng mà giá trị khác giá trị hiện tại
arrayFirstIndex(i -> array[i] != current_value, arrayEnumerate(array))
```

**Bước 4 — Sinh tất cả prefix path.** Path Exploration hiển thị **mọi prefix** (tiền tố) của path. Ví dụ với path `A → B → C → D`:

```
Prefix 1: [A]
Prefix 2: [A, B]
Prefix 3: [A, B, C]
Prefix 4: [A, B, C, D]
```

```sql
ARRAY_SLICE(path_array, 0, offset)  -- cắt mảng từ đầu đến vị trí offset
```

> **Note — Tại sao cần prefix?** Vì khi người dùng tương tác với biểu đồ Path Exploration, họ mở rộng từng bước một: click vào node ở step 1 → hiện step 2 → click tiếp → hiện step 3. Mỗi lần click là một prefix query. Nếu chỉ lưu path đầy đủ, mỗi query phải quét lại toàn bộ path và cắt — rất chậm. Lưu sẵn prefix giúp query O(1).

Độ dài path tối đa: **100 bước** (trước dedup). Sau dedup, độ dài luôn ≤ 100.

### 1.4 Logic lấy mẫu (Sampling)

Lượng event của MoMo cực lớn (hàng chục triệu user/ngày). Apollo sử dụng **10% user sampling** để Path Exploration chạy nhanh và tiết kiệm tài nguyên.

- **Phương pháp:** Lấy ngẫu nhiên 10% người dùng mỗi ngày
- **Bảng sampling:** `apollo_path_sampling_segment`
- **Tính chất:** Ngẫu nhiên, làm mới hàng ngày, độc lập giữa các ngày
- **Quy đổi:** Khi so sánh sample với full, nhân số liệu sample với 10 để quy đổi về cùng thang

> **Note:** Mục đích của toàn bộ framework này là **chứng minh rằng 10% đó đủ đại diện cho 100%**. Nếu không chứng minh được, mọi insight từ Apollo đều có thể sai lệch.

## 2. Mục tiêu kiểm định

Cần chứng minh 3 điều:

### 2.1 Tính đại diện (Representativeness)

Mẫu 10% phải tái tạo được phân bố hành vi của toàn bộ quần thể: tần suất path, chỉ số hành vi user, độ phủ node.

> **Note — Ví dụ:** Nếu trong full population, 30% người dùng đi theo path `Home → Chuyển tiền → Xác nhận`, thì trong mẫu 10% con số đó cũng phải xấp xỉ 30%.

### 2.2 Chênh lệch là ngẫu nhiên, không hệ thống (Gap Nature)

Sampling luôn có chênh lệch — đó là bản chất thống kê. Nhưng chênh lệch đó phải là **dao động ngẫu nhiên** (random fluctuation / noise), không phải **thiên lệch hệ thống** (systematic bias).

> **Note — Ví dụ về bias hệ thống:** Nếu sampling vô tình chọn nhiều user iOS hơn Android → tất cả path liên quan đến tính năng chỉ có trên Android sẽ bị undercount. Đây là bias, không phải noise.

### 2.3 Đảm bảo độ chính xác của Apollo (Accuracy Guarantee)

Apollo đảm bảo accuracy cao cho các path có traffic ≥ 1.000 user/ngày. Các path dưới ngưỡng này là trường hợp hiếm (niche/edge case) với phương sai tự nhiên cao — không cần đảm bảo.

> **Note — Tại sao 1.000?** Với tỷ lệ sampling 10%, một path 1.000 user sẽ có ~100 user trong mẫu. Theo định lý giới hạn trung tâm (Central Limit Theorem), 100 quan sát đủ để phân bố mẫu hội tụ về phân bố chuẩn, cho phép kiểm định thống kê có ý nghĩa.

## 3. Pipeline ETL đầu-cuối

Pipeline tạo ra 2 bộ dữ liệu song song (FULL và SAMPLE), sau đó chạy so sánh kiểm định.

```
Bước 1: Xử lý Raw Event
  APP_EVENT.EVENTS → raw_apollo_path_event
  (trích xuất, forward-fill, lọc event hợp lệ)

Bước 2: Xây dựng Session Path
  raw_apollo_path_event → apollo_session_array
  (nhóm event thành mảng theo session, dedup liên tiếp)

Bước 3: Sinh Path Prefix (FULL — toàn bộ user)
  apollo_session_array → apollo_path_prefix_full
  (bung tất cả prefix bằng ARRAY_SLICE)

Bước 4: Sinh Path Prefix (SAMPLE — 10% user)
  apollo_session_array ⋈ apollo_path_sampling_segment → apollo_path_prefix_sample
  (cùng logic, chỉ lọc user nằm trong mẫu 10%)

Bước 5: Thống kê Traffic theo Node
  → apollo_node_traffic_day_dim
  (đếm distinct user mỗi node mỗi ngày, tách theo miniapp/screen/event/service)

Bước 6: Kiểm định Coverage
  So sánh độ phủ node và traffic giữa sample vs full
  (chỉ cho node có traffic ≥ 1.000 user/ngày)

Bước 7: Kiểm định Thống kê (4 phase — xem Phần 4)
```

### Schema bảng Raw Event

| Trường | Mô tả | Ghi chú |
|--------|-------|---------|
| `event_date` | Ngày phân vùng (partition) | Dùng để lọc theo ngày |
| `event_timestamp` | Thời điểm chính xác của event | Dùng để sắp xếp trong session |
| `agent_id` | Định danh người dùng | Đây là user_id trong hệ thống MoMo |
| `event_name` | Tên sự kiện | Ví dụ: `feature_trans_result` |
| `screen_name` | Tên màn hình | Ví dụ: `payx payment` |
| `service_name` | Tên dịch vụ | Ví dụ: `transfer` |
| `device_os` | Hệ điều hành | `ios` hoặc `android` |
| `session_id` | ID session | Lấy từ `momo_session_id_v2` |

## 4. Kiểm định Thống kê — 4 Phase

### Phase 1 — Kiểm định phân bố Path (Path Distribution Validation)

So sánh phân bố tần suất path giữa FULL và SAMPLE (đã nhân ×10).

| Chỉ số | Công thức | Ý nghĩa |
|--------|-----------|---------|
| Chênh lệch tuyệt đối (absolute gap) | `sample_scaled_users - full_users` | Chênh bao nhiêu user (đã quy đổi) |
| Chênh lệch phần trăm (percentage gap) | `(sample_scaled - full) / full` | Chênh bao nhiêu % so với thực tế |

> **Note — Cách đọc kết quả:** Nếu một path có full = 10.000 user và sample_scaled = 10.300 user → absolute gap = +300, pct_gap = +3%. Nghĩa là sampling ước lượng thừa 3% cho path này. Nếu gap phân bố đều quanh 0 (có dương có âm) → noise. Nếu gap luôn dương hoặc luôn âm → bias.

### Phase 2 — Kiểm định cấp User (User-Level Validation)

So sánh phân bố các chỉ số hành vi per-user giữa sample và full:

| Chỉ số | Đo lường cái gì | Tại sao quan trọng |
|--------|-----------------|-------------------|
| Số session mỗi user | Tần suất sử dụng app | User heavy-use vs casual |
| Số event mỗi user | Độ sâu tương tác | User thao tác nhiều vs ít |
| Số miniapp riêng biệt | Độ rộng hành vi | User khám phá nhiều vs chuyên dùng 1 feature |
| Độ sâu path trung bình | Độ phức tạp hành trình | User đi sâu bao nhiêu bước |

> **Note — Logic kiểm định:** Nếu mẫu 10% có phân bố user metrics tương tự full → sampling không thiên lệch về bất kỳ nhóm hành vi nào (không chọn quá nhiều power user hay quá nhiều casual user).

### Phase 3 — Kiểm định phân tầng theo điểm bắt đầu (Stratified Validation)

Với mỗi miniapp là điểm bắt đầu (starting point) có ≥ 1.000 user/ngày, tính **Z-score nhị thức** (binomial Z-score):

```
Z = (observed_sample - expected_sample) / SE

Trong đó:
  expected_sample = population_size × 0.1     (kỳ vọng: 10% quần thể)
  SE = sqrt(population_size × 0.1 × 0.9)     (sai số chuẩn nhị thức)
```

> **Note — Z-score nghĩa là gì?** Z-score đo "mẫu lệch bao nhiêu lần sai số chuẩn so với kỳ vọng". |Z| < 2 → bình thường (95% tin cậy). |Z| > 3 → bất thường (99.7% tin cậy) → có thể có bias tại miniapp đó.

Sau đó, phân nhóm miniapp thành 3 tầng theo lượng traffic (NTILE(3): cao/trung/thấp) và tính trung bình + độ lệch chuẩn Z-score mỗi tầng.

> **Note — Tại sao phân tầng?** Để phát hiện liệu bias có tương quan với mức độ phổ biến của miniapp hay không. Ví dụ: nếu tầng "traffic thấp" có mean Z = +2.5 nhưng tầng "traffic cao" có mean Z = +0.1 → sampling thiên lệch với miniapp ít phổ biến.

### Phase 4 — Kiểm định Over-Dispersion (Phân tán quá mức)

Kiểm tra liệu phương sai của các Z-score có vượt quá phương sai mà mô hình nhị thức dự đoán hay không.

```
φ = Σ(Z²) / (n - 1)
```

| Giá trị φ | Diễn giải | Hành động |
|-----------|-----------|-----------|
| 0.8 – 1.2 | Phù hợp tốt — phương sai khớp kỳ vọng nhị thức | Sampling hợp lệ |
| 1.2 – 1.5 | Phân tán nhẹ — phương sai hơi cao, chấp nhận được | Theo dõi, không cần hành động |
| > 2.0 | Phân tán nghiêm trọng — rất có thể có bias hệ thống | Cần điều tra nguyên nhân gốc |

> **Note — Trực giác về φ:** Nếu sampling hoàn toàn ngẫu nhiên, mỗi Z-score sẽ tuân theo phân bố chuẩn N(0,1), nghĩa là Z² tuân theo χ²(1). Khi lấy trung bình của nhiều Z², kết quả sẽ xấp xỉ 1. Nếu φ >> 1, tức là Z-score dao động mạnh hơn dự kiến → có yếu tố bên ngoài (bias) gây ra phương sai thêm.

## 5. Chiến lược gán trọng số (Weighting Strategy)

Phân bố traffic của path tuân theo **heavy-tailed distribution** (phân bố đuôi nặng) — một vài path phổ biến chiếm phần lớn traffic, trong khi rất nhiều path hiếm có traffic cực thấp.

> **Note — Vấn đề:** Path hiếm (ví dụ: chỉ 50 user/ngày) tự nhiên sẽ có percentage gap rất lớn (sampling 5 user thay vì 5, chênh 1 user = chênh 20%). Nếu tính trung bình gap không trọng số, các path hiếm này sẽ kéo cao gap trung bình một cách không công bằng, trong khi chúng hầu như không ảnh hưởng đến trải nghiệm sản phẩm.

Giải pháp: **Gán trọng số theo traffic**

```
node_weight = node_users / total_users_same_type
weighted_gap = gap_ratio × node_weight
```

> **Note:** `total_users_same_type` là tổng user của tất cả node cùng loại (ví dụ: tổng user của tất cả miniapp). Cách này đảm bảo path phổ biến (quan trọng nhất cho quyết định sản phẩm) đóng góp tỷ lệ tương xứng vào chỉ số gap cuối cùng.

## 6. Tiêu chí đạt (Pass Criteria)

Sampling được coi là **hợp lệ thống kê** khi ĐỒNG THỜI thỏa tất cả:

| Chỉ số | Ngưỡng | Lý do |
|--------|--------|-------|
| P95 Z-score | < 3.0 | 95% miniapp không có bias đáng kể (chỉ 5% được phép |Z| > 3) |
| Chênh lệch có trọng số trung bình | < 3% | Sai số trung bình (đã tính trọng số traffic) dưới 3% |
| Hệ số phân tán φ | 0.8 – 1.2 | Phương sai quan sát khớp với lý thuyết nhị thức |

> **Note — Tại sao cần cả 3?** Mỗi tiêu chí kiểm tra một khía cạnh khác nhau:
> - Z-score kiểm tra từng miniapp riêng lẻ (có miniapp nào bị bias không?)
> - Weighted gap kiểm tra tổng thể (trung bình chênh lệch có nhỏ không?)
> - φ kiểm tra mô hình (sampling có thực sự tuân theo phân bố nhị thức không?)

## 7. Bảng đầu ra cuối cùng (Final Output)

Pipeline phải tạo ra 5 bảng kiểm định:

| Bảng đầu ra | Nội dung | Dùng để trả lời câu hỏi |
|-------------|----------|-------------------------|
| `coverage_report` | % node được phủ và % traffic được phủ (sample vs full) | "Sampling có bỏ sót node quan trọng nào không?" |
| `gap_distribution` | Chênh lệch tuyệt đối và phần trăm cho từng path | "Path nào chênh nhiều nhất? Chênh lệch phân bố ra sao?" |
| `z_score_distribution` | Z-score từng miniapp + phân tầng theo volume | "Miniapp nào bị bias? Bias có tương quan với mức traffic không?" |
| `dispersion_test` | Hệ số φ theo ngày | "Phương sai Z-score có vượt kỳ vọng nhị thức không?" |
| `weighted_gap_summary` | Chênh lệch tổng hợp có trọng số traffic | "Nhìn tổng thể, sampling chênh bao nhiêu %?" |

Mỗi bảng phải kèm **diễn giải thống kê** (interpretation) và **kết luận kiểm định cuối cùng** (validation conclusion) khẳng định rõ ràng: "Mẫu 10% CÓ / KHÔNG đủ đại diện vì [bằng chứng cụ thể]."
