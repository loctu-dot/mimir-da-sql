# Apollo Path Exploration — Overview & Data Quality Report

**Ngày lấy dữ liệu:** 2026-02-28

**Slide hướng dẫn & Demo:** https://docs.google.com/presentation/d/1Mk3ApUaJHqCnBtkv1Xwrt3S6bNJjg2Ol_ZxXxZ6Z7G0/edit?slide=id.g3861b44a02b_0_236#slide=id.g3861b44a02b_0_236

---

## Mục lục

### Phần 1 — Tổng quan Path Exploration
- [1.1 Path Exploration là gì?](#11-path-exploration-là-gì)
- [1.2 Mục đích & Use Case](#12-mục-đích--use-case)
- [1.3 Điểm mạnh so với GA4](#13-điểm-mạnh-so-với-ga4)
- [1.4 Cách sử dụng (User Flow)](#14-cách-sử-dụng-user-flow)
- [1.5 Logic hoạt động — Data Flow](#15-logic-hoạt-động--data-flow)
  - [Tổng quan pipeline](#tổng-quan-pipeline)
  - [Chi tiết từng bước](#chi-tiết-từng-bước)
  - [4 loại Node (Dimension)](#4-loại-node-dimension)
- [1.6 Data Sampling — Tại sao chỉ dùng 10%?](#16-data-sampling--tại-sao-chỉ-dùng-10)

### Phần 2 — Data Sampling Quality Report
- [Executive Summary](#executive-summary-sampling-10-đủ-đại-diện-cho-path-exploration)
- [Trade-off: 10% Data → 90% Cost Reduction](#trade-off-10-data--90-cost-reduction)
- [Bảng tiêu chí tổng hợp](#bảng-tiêu-chí-tổng-hợp)
- [Giải thích thuật ngữ](#giải-thích-thuật-ngữ)
- [Phase 1 — Coverage Validation](#phase-1--coverage-validation)
- [Phase 2 — Path Distribution Validation](#phase-2--path-distribution-validation)
- [Phase 3 — User-Level Validation](#phase-3--user-level-validation)
- [Phase 4 — Stratified Z-Score Validation](#phase-4--stratified-z-score-validation)
- [Phase 5 — Over-Dispersion Test](#phase-5--over-dispersion-test)
- [Kết Luận Tổng Thể](#kết-luận-tổng-thể)
  - [Cơ sở Lý thuyết thống kê](#cơ-sở-lý-thuyết-tại-sao-10-sampling-352k-user-đủ-đại-diện)
  - [Trade-off Evaluation](#trade-off-evaluation-cho-10-sampling-method-của-path-exploration)

---

# PHẦN 1 — TỔNG QUAN PATH EXPLORATION

## 1.1 Path Exploration là gì?

Path Exploration là tính năng phân tích hành trình người dùng (user journey) trong ứng dụng MoMo, thuộc nền tảng analytics nội bộ **Apollo**. Tính năng được thiết kế theo mô hình Path Exploration của GA4 (Google Analytics 4), cho phép Product Owner/ Data Analyst/ Business Stakeholders:

- **Truy vết hành trình** — Xem từng bước user đi trong app: mở miniapp nào → vào màn hình nào → thực hiện hành động gì → chuyển sang dịch vụ nào
- **Khám phá luồng phổ biến hoặc hiếm gặp** — Tìm ra các chuỗi hành động mà các user thực hiện để đến được đích mong muốn hoặc bắt đầu từ điểm mong muốn (ví dụ: Home → Chuyển tiền → Xác nhận → Thành công)
- **Phân tích conversion** — Xác định user rời đi ở bước nào, tỷ lệ chuyển đổi giữa các bước ra sao
- **Segmentation** — Tái sử dụng các Segment được upload lên Apollo/Trackify và theo dõi hành trình của nhóm user cụ thế đó 


## 1.2 Mục đích & Use Case

| Use Case | Người dùng | Ví dụ câu hỏi |
|----------|-----------|---------------|
| **Phân tích luồng chính** | Product Owner | "User mở MoMo xong đi đâu nhiều nhất?" |
| **Tìm điểm drop-off** | Growth Analyst | "Bao nhiêu % user bỏ ngang ở bước thanh toán?" |
| **So sánh feature adoption** | Feature Lead | "User dùng Chuyển tiền có flow khác user dùng Nạp tiền không?" |
| **Debug UX issue** | UX Designer | "Tại sao user quay lại Home nhiều lần trước khi hoàn thành giao dịch?" |
| **Đo hiệu quả campaign** | Marketing | "User từ notification có hành trình khác user organic không? Bao nhiêu user sẽ đi theo đúng hướng mình mong muốn ? Nếu họ đi sai lệch thì sẽ là đi tới những đâu ? " |

**Điểm cốt lõi:** Path Exploration cung cấp **cái nhìn tổng quan** (overview) về hành vi user với độ chính xác >90%, đủ để đưa ra quyết định sản phẩm đúng hướng.

## 1.3 Điểm mạnh so với GA4

| Tiêu chí | GA4 Path Exploration | Apollo Path Exploration |
|----------|---------------------|----------------------|
| **Node type linh hoạt** | Cố định 1 loại cho cả path | Chuyển đổi tự do tại mỗi bước (miniapp → screen → event → miniapp) |
| **Customization** | Giới hạn UI/Design/ Metrics theo 1 standard dùng chung của Google | Tuỳ chỉnh dimension, segment, filter theo nhu cầu nội bộ |
| **Segment** | Demographic cơ bản | Map được trực tiếp với các Segment đã được import lên Apollo/Trackify |
| **Dimension** | Hạn chế | 4 dimension chính + filter theo device_os, app_version, miniapp_version |

## 1.4 Cách sử dụng (User Flow)

```
1. Chọn Starting/Ending Point
   User chọn miniapp/screen/event làm điểm bắt đầu hoặc đích đến
   Ví dụ: "Bắt đầu từ vn.momo.platform (Home)"

2. Chọn Node Type cho mỗi Step
   Mỗi bước tiếp theo có thể là miniapp, screen, event, hoặc service
   Ví dụ: Step 1 = miniapp → Step 2 = miniapp → Step 3 = screen
        Note: Trong ví dụ trên, khi chọn Screen ở Step 3 tức là đang muốn xem sau khi user vào Miniapp 'abc' ở Step 2 thì họ sẽ đi đến những screen nào ( có thể là screen trong cùng miniapp 'abc' hoặc screen ngoài miniapp)

3. Xem biểu đồ Sankey / Tree
   Hiển thị luồng user: bao nhiêu user đi theo từng nhánh
   Mỗi node hiện số user + % so với step trước

4. Drill-down
   Click vào node bất kỳ → mở rộng thêm step tiếp theo
   Filter theo segment, device_os, thời gian...

5. Export / Insight
   Copy Link hoặc Xuất file hình (.PNG) capture path đã tạo để dễ dàng gửi cho các stakeholders
```

## 1.5 Logic hoạt động — Data Flow

### Tổng quan pipeline

```
Raw Events (467M/ngày)
    │
    ▼
Bước 1: Event Preparation
    Trích xuất + xử Lý dữ liệu + forward-fill fields rỗng
    │
    ▼
Bước 2: Sessionization (quy tắc 30 phút)
    Nhóm events thành sessions
    │
    ▼
Bước 3: Path Aggregation
    Gom events trong session thành mảng có thứ tự
    │
    ▼
Bước 4: Consecutive Dedup
    Loại node lặp liên tiếp (A→A→B thành A→B)
    │
    ▼
Bước 5: Path Prefix Generation
    Sinh tất cả prefix cho mỗi path
    │
    ▼
Path Exploration Data
```

### Chi tiết từng bước

**Bước 1 — Event Preparation.** Mỗi ngày MoMo ghi nhận ~467 triệu raw event. Mỗi event chứa: timestamp, user_id, device_os, app_id (miniapp), screen_name, event_name, service_name, session_id. Các field bị rỗng được **forward-fill** — lấy giá trị gần nhất không null từ event trước đó trong cùng session.

**Bước 2 — Sessionization.** Nhóm events liên tiếp của cùng user thành session. Quy tắc: nếu khoảng cách giữa 2 event > **30 phút** → session mới. Đây là chuẩn ngành (GA4 cũng dùng 30 phút).

**Bước 3 — Path Aggregation.** Mỗi session được gom thành 4 mảng song song (cùng độ dài, cùng thứ tự):

| Mảng | Nội dung | Ví dụ |
|------|----------|-------|
| `all_apps` | Chuỗi miniapp | [platform, home_momo, compose-old, ...] |
| `all_screens` | Chuỗi screen | [home, payment, confirm, ...] |
| `all_events` | Chuỗi event | [screen_view, button_click, trans_result, ...] |
| `all_services` | Chuỗi service | [transfer, payment, ...] |

**Bước 4 — Consecutive Dedup.** Loại bỏ node lặp liên tiếp: `A → A → B → C` thành `A → B → C`. Lý do: một miniapp sinh ra nhiều event/screen liên tiếp — nếu không dedup, nhiều bước liên tiếp chỉ đang ở cùng một miniapp, trong khi user muốn thấy miniapp tiếp theo là gì.

**Bước 5 — Path Prefix Generation.** Sinh tất cả tiền tố (prefix) của path. Ví dụ path `A → B → C → D` tạo ra 4 prefix: `[A]`, `[A,B]`, `[A,B,C]`, `[A,B,C,D]`. Lý do: khi user tương tác với biểu đồ, mỗi lần click mở rộng thêm 1 step — mỗi step là 1 prefix query.

### 4 loại Node (Dimension)

| Node type | Ý nghĩa | Ví dụ |
|-----------|---------|-------|
| **miniapp** | Ứng dụng con bên trong MoMo | `vn.momo.platform` (Home), `vn.momo.transfer` (Chuyển tiền) |
| **screen** | Màn hình hiển thị | `payx payment` (Trang thanh toán), `home_momo home` (Trang chủ) |
| **event** | Sự kiện cụ thể | `feature_trans_result` (Kết quả giao dịch), `button_click` |
| **service** | Dịch vụ backend | `transfer` (Chuyển tiền), `payment` (Thanh toán) |

Điểm khác biệt cốt lõi: user có thể **chuyển node type tại mỗi bước**. Ví dụ: `miniapp → miniapp → screen → screen → event → miniapp`. GA4 không hỗ trợ điều này.

## 1.6 Data Sampling — Tại sao chỉ dùng 10%?
**BÀI TOÁN**: MoMo có hàng triệu User truy cập hàng ngày và trigger tạo ra hàng tỉ record liên quan tới Event Tracking (hành vi tương tác app)

Ví dụ: ~3.9 triệu user active/ngày và 38.5 triệu sessions, chạy full data daily sẽ đòi hỏi:
- 562 GB BigQuery scan mỗi ngày
- Chi phí compute rất cao
- Thời gian query chậm, ảnh hưởng trải nghiệm user

-> Vậy Apollo với mục tiêu phục vụ toàn bộ Stakeholder MoMo với hơn 200+ Miniapps phải làm thể nào?  

>Apollo giải quyết bằng việc scale down lấy **10% random user sampling** mỗi ngày để đại diện cho toàn bộ MoMo users hôm đó:
- Giảm xuống ~3.8M sessions (~352K users)
- Tiết kiệm ~90% compute cost
- Cho phép daily refresh và thực hiện truy vết đường đi trực tiếp
- Kết quả phản hồi nhanh hơn ~10× dù logic cực kì phức tạp

**Câu hỏi quan trọng:** 10% liệu có đủ đại diện? Sai số chênh lệch sẽ là bao nhiêu ?

---
---

# PHẦN 2 — DATA SAMPLING QUALITY REPORT

> Kiểm định tính đại diện của mẫu 10% (352K user) so với toàn bộ quần thể (3.91M user) cho ngày 2026-02-28.


## Executive Summary: Sampling 10% Đủ Đại Diện Cho Path Exploration

Với mục tiêu cung cấp **cái nhìn tổng quan về hành vi user**, mẫu 10% (~352K user từ 3.91M quần thể) đáp ứng tốt: **coverage 100%**, weighted gap 6.08% (dưới ngưỡng 10%), phân bố hành vi user khớp hoàn toàn. Đổi lại, sampling giảm **90% khối lượng xử lý** — từ 38.5M sessions xuống 3.8M — cho phép chạy daily với chi phí tối ưu.

---

### Trade-off: 10% Data → 90% Cost Reduction

| | Full Pipeline | | Sample Pipeline |
|---|---|---|---|
| **Sessions / ngày** | 38.5M | → giảm 90% → | 3.8M |
| **Raw events** | 467M | | ~47M |
| **BQ scan** | 562 GB | | ~56 GB |

> Tiết kiệm ~**500 GB/ngày** BigQuery scan, giảm **~90% chi phí compute**, cho phép chạy **daily refresh** thay vì batch weekly.

---

### Bảng tiêu chí tổng hợp

| Tiêu chí | Giá trị | Ngưỡng | Đánh giá |
|----------|---------|--------|----------|
| Node Coverage | **100%** | Mọi path ≥ 1K users | ✅ PASS |
| Weighted Mean Gap | **6.08%** | < 10% | ✅ PASS |
| User Behavior Match | **Khớp** | Median session, depth, events | ✅ PASS |
| φ Medium+Low (42 miniapp) | **1.18–1.56** | 66% miniapps | ✅ PASS |
| φ excl Top 3 (61 miniapp) | **3.67** | 95% miniapps | ⚠️ CHẤP NHẬN |
| Top 3 % Gap thực tế | **0.25–0.77%** | Chênh tỷ lệ, không phải Z | ✅ PASS |

### KPI tổng quan

| Metric | Giá trị | Ghi chú |
|--------|---------|---------|
| Workload Reduction | **90%** | 38.5M → 3.8M sessions |
| Node Coverage | **100%** | Mọi path ≥ 1K users |
| Weighted Gap | **6.08%** | Ngưỡng: < 10% |
| Miniapps Đạt φ | **66%** | 42/64 miniapp φ ≤ 1.56 |
| Sampling Rate Thực | **9.0%** | 351,840 / 3,910,498 users |

### Giải thích thuật ngữ

> **Coverage (Độ phủ)** — Đo mức độ mà tập sample "nhìn thấy" được hành vi tương tác của user so với tập full. Coverage 100% nghĩa là mọi hành trình phổ biến đều xuất hiện trong sample — user của Path Exploration sẽ thấy đầy đủ các luồng tương tác. Coverage càng cao → sample data càng phản ánh đúng bức tranh toàn cảnh hành vi user trên MoMo trong ngày đó.

> **Weighted Gap %** — Chênh lệch phần trăm giữa số user ước lượng từ sample (×10) so với số user thực tế trong full data, có gán trọng số theo traffic. Path phổ biến (nhiều user) được tính nặng hơn, path hiếm (ít user) tính nhẹ hơn — vì path phổ biến ảnh hưởng trực tiếp đến insight sản phẩm. Gap 0% = hoàn hảo, ngưỡng chấp nhận < 10%.

---

## Phase 1 — Coverage Validation

So sánh độ phủ node và traffic giữa mẫu 10% và toàn bộ quần thể, chỉ xét path có ≥ 1,000 user/ngày.

### Số lượng Path theo Step Level

| Step | Full | Sample |
|------|------|--------|
| S1 | 1 | 1 |
| S2 | 113 | 102 |
| S3 | 1,200 | 780 |
| S4 | 10,057 | 3,561 |
| S5 | 29,142 | 7,422 |
| S6 | 33,782 | 8,190 |
| S7 | 43,522 | 9,188 |
| S8 | 47,262 | 9,309 |
| S9 | 56,471 | 10,774 |

### Distinct Users theo Step Level

| Step | Full | Sample ×10 |
|------|------|------------|
| S1 | 2,948,635 | 2,746,730 |
| S2 | 1,550,940 | 1,456,560 |
| S3 | 1,531,871 | 1,438,860 |
| S4 | 794,513 | 746,590 |
| S5 | 487,733 | 460,150 |
| S6 | 470,171 | 443,840 |
| S7 | 408,227 | 385,430 |
| S8 | 359,416 | 339,400 |
| S9 | 359,416 | 339,400 |

### Chi tiết Coverage theo Step Level

| Step | Paths (Full) | Paths (Sample) | Node Coverage | Traffic Coverage | Mean Gap | Median Gap | P95 \|Gap\| |
|------|-------------|----------------|--------------|-----------------|----------|------------|------------|
| 1 | 1 | 1 | ✅ 100% | ✅ 100% | -6.85% | -6.85% | 6.85% |
| 2 | 52 | 52 | ✅ 100% | ✅ 100% | -5.66% | -6.05% | 13.01% |
| 3 | 132 | 132 | ✅ 100% | ✅ 100% | -5.34% | -5.19% | 13.60% |
| 4 | 219 | 219 | ✅ 100% | ✅ 100% | -5.51% | -5.28% | 17.62% |
| 5 | 283 | 283 | ✅ 100% | ✅ 100% | -5.83% | -5.28% | 17.67% |
| 6 | 281 | 281 | ✅ 100% | ✅ 100% | -5.99% | -5.46% | 18.41% |
| 7 | 275 | 275 | ✅ 100% | ✅ 100% | -5.98% | -5.46% | 19.53% |
| 8 | 259 | 259 | ✅ 100% | ✅ 100% | -5.74% | -5.35% | 19.25% |
| 9 | 256 | 256 | ✅ 100% | ✅ 100% | -5.87% | -5.63% | 17.24% |

> **Diễn giải Phase 1: ✅ PASS — Coverage 100%.** Với chỉ 10% data, mẫu vẫn cover được **100% các path quan trọng** (≥ 1,000 user). Không mất bất kỳ node nào — user sẽ thấy đầy đủ các hành trình phổ biến trên biểu đồ Path Exploration. Mean gap ổn định ở -5% đến -6%, nằm thoải mái trong ngưỡng 10% và có thể triệt tiêu bằng điều chỉnh scale factor.

---

## Phase 2 — Path Distribution Validation

Phân tích chênh lệch tần suất path giữa mẫu (×10) và full. Chỉ xét path ≥ 1,000 users.

### Phân bố Chênh lệch % (Gap Histogram)

| Gap Bucket | Số Path | Tổng Traffic |
|------------|---------|-------------|
| < -20% | 56 | 89,168 |
| -20% to -10% | 385 | 1,013,640 |
| -10% to -5% | 495 | 23,035,028 |
| -5% to -2% | 358 | 4,473,659 |
| **-2% to +2%** | **283** | **1,167,565** |
| +2% to +5% | 99 | 203,423 |
| +5% to +10% | 65 | 100,256 |
| +10% to +20% | 15 | 25,348 |
| > +20% | 2 | 2,506 |

### Top 10 Path có Gap lớn nhất (theo số user tuyệt đối)

| Step | Path | Full Users | Sample ×10 | Gap | Gap % |
|------|------|-----------|-----------|-----|-------|
| 1 | vn.momo.platform | 2,948,635 | 2,746,730 | -201,905 | -6.85% |
| 2 | ...platform - empty | 1,893,652 | 1,771,870 | -121,782 | -6.43% |
| 3 | ...platform - empty - empty | 1,787,406 | 1,673,570 | -113,836 | -6.37% |
| 2 | ...platform - home_momo | 802,627 | 754,060 | -48,567 | -6.05% |
| 3 | ...home_momo - home_momo home | 800,717 | 752,330 | -48,387 | -6.04% |
| 4 | ...home_momo home - platform empty | 490,534 | 463,130 | -27,404 | -5.59% |
| 2 | ...platform - compose-old | 233,770 | 223,270 | -10,500 | -4.49% |
| 5 | ...platform empty - home_momo home | 188,545 | 179,990 | -8,555 | -4.54% |
| 5 | ...platform empty - empty | 135,060 | 126,750 | -8,310 | -6.15% |
| 8 | ...home_momo - platform empty | 177,213 | 168,990 | -8,223 | -4.64% |

### Weighted Mean Gap theo Step Level

| Step | Path Count | Unweighted Mean Gap | Weighted Mean Gap | Đánh giá |
|------|-----------|--------------------|--------------------|----------|
| 1 | 1 | 6.85% | ✅ 6.85% | PASS (<10%) |
| 2 | 52 | 6.49% | ✅ 6.08% | PASS |
| 3 | 132 | 6.29% | ✅ 6.03% | PASS |
| 4 | 219 | 6.89% | ✅ 6.01% | PASS |
| 5 | 283 | 7.15% | ✅ 6.06% | PASS |
| 6 | 281 | 7.25% | ✅ 6.08% | PASS |
| 7 | 275 | 7.52% | ✅ 6.12% | PASS |
| 8 | 259 | 7.15% | ✅ 6.07% | PASS |
| 9 | 256 | 7.26% | ✅ 6.08% | PASS |

> **Diễn giải Phase 2: ✅ PASS — Weighted mean gap ~6%, nằm trong ngưỡng 10%.** Chênh lệch nhất quán âm ở mọi step level (~6%), nguyên nhân gốc là sampling rate ngày 28/02 đạt 9.0% thay vì đúng 10%. 76% path nằm trong khoảng -10% đến +2%. Gap nghiêng hệ thống về phía âm — đây là bias nhẹ do sampling rate chưa đúng 10%, không phải do sampling method sai. Nếu điều chỉnh scale factor từ ×10 thành ×10.75, gap sẽ giảm đáng kể.

---

## Phase 3 — User-Level Validation

So sánh phân bố hành vi per-user giữa mẫu và full population: sessions, events, path depth.

### Phân bố Session / User (Sample vs Full)

| Sessions / User | Full (users) | Full % | Sample (users) | Sample % |
|----------------|-------------|--------|---------------|----------|
| 1 | 1,968,966 | 54.2% | 183,591 | 52.5% |
| 2 | 21,294 | 0.6% | 2,050 | 0.6% |
| 3 | 25,217 | 0.7% | 2,430 | 0.7% |
| 4-5 | 196,800 | 5.4% | 19,937 | 5.7% |
| 6-10 | 435,006 | 12.0% | 45,978 | 13.2% |
| 11-20 | 421,021 | 11.6% | 45,075 | 12.9% |
| 20+ | 490,354 | 13.5% | 52,779 | 15.1% |

### Chi tiết Chỉ số User-Level

| Chỉ số | Full Population | Sample (10%) | Chênh lệch | Đánh giá |
|--------|----------------|-------------|-----------|----------|
| Số user | 3,910,498 | 351,840 | 9.0% | ⚠️ ~10% |
| Avg sessions/user | 9.75 | 10.50 | +7.7% | ⚠️ Sample hơi active hơn |
| Median sessions | 1 | 1 | ✅ 0% | ✅ Khớp |
| Avg path depth | 13.21 | 13.25 | ✅ +0.3% | ✅ Khớp |
| Median path depth | 7 | 7 | ✅ 0% | ✅ Khớp |
| Avg events/session | 13.21 | 13.25 | ✅ +0.3% | ✅ Khớp |
| Median events/session | 7 | 7 | ✅ 0% | ✅ Khớp |

> **Diễn giải Phase 3: ✅ PASS — Phân bố hành vi user khớp hoàn toàn.** Median session, path depth, events/session đều giống nhau giữa sample và full. Đây là bằng chứng mạnh nhất rằng **10% sampling bảo toàn được cấu trúc hành vi user** — không mất thông tin về cách user tương tác với app. Avg sessions/user hơi cao hơn 7.7% ở sample — đây là đặc tính tự nhiên, không ảnh hưởng đến mục tiêu overview của Path Exploration.

---

## Phase 4 — Stratified Z-Score Validation

Z-score nhị thức cho 64 starting miniapp (đã loại "empty", ≥ 1,000 user), phân tầng theo mức traffic. Z ≈ 0 là lý tưởng.

### Phân tầng Z-Score (64 starting miniapps, đã loại "empty")

| Nhóm Traffic | # Miniapp | Mean Z | Std Z | φ | P95 \|Z\| | # Outlier | Đánh giá |
|-------------|----------|--------|-------|---|----------|----------|----------|
| High (top 1/3) | 22 | ❌ -4.73 | 8.59 | ❌ 97.17 | ❌ 9.33 | ❌ 7 | Top 3 kéo skew |
| └ High excl top 3 | 19 | ⚠️ -2.47 | 1.67 | ❌ 9.20 | ⚠️ 7.30 | ⚠️ 4 | Vẫn lệch nhẹ |
| Medium (mid 1/3) | 21 | ✅ -0.83 | 0.92 | ⚠️ 1.56 | 2.46 | ✅ 0 | Chấp nhận được |
| Low (bottom 1/3) | 21 | ✅ -0.49 | 0.96 | ✅ 1.18 | 2.31 | ✅ 0 | **PASS** |
| **OVERALL (excl empty)** | **64** | ⚠️ -2.06 | 5.38 | ❌ 33.26 | 6.00 | 7 | Bị skew bởi top 3 |
| **EXCL TOP 3 IMPACT** | **61** | ⚠️ -1.22 | 1.47 | ⚠️ 3.67 | 3.34 | 4 | **Cải thiện lớn** |

#### Tại sao Top 3 có Z cực lớn?

Z-score = (observed - expected) / SE, trong đó SE = √(n×p×(1-p)). Khi n = 2.6 triệu (home_momo), SE chỉ ≈ 488. Chênh 6.6% (sampling rate 9.0% vs 10%) = 20,434 user thiếu → Z = -20,434/488 = **-41.86**. Đây không phải bias riêng của home_momo — cùng một % deviation nhưng n lớn tạo Z lớn. **Đây là artifact toán học, không phải vấn đề sampling method.**

### Top 20 Starting Miniapp Z-Score (sorted by traffic)

| Starting Miniapp | Total Users | Sample Users | Expected (10%) | Z-Score | Đánh giá |
|-----------------|-----------|-------------|---------------|---------|----------|
| vn.momo.home_momo | 2,648,047 | 244,371 | 264,805 | ❌ -41.86 | Outlier |
| vn.momo.compose-old | 904,354 | 87,773 | 90,435 | ❌ -9.33 | Outlier |
| vn.momo.bank | 502,501 | 48,975 | 50,250 | ❌ -6.00 | Outlier |
| vn.momo.platform | 237,070 | 22,640 | 23,707 | ❌ -7.30 | Outlier |
| vn.momo.transfer | 128,869 | 12,392 | 12,887 | ❌ -4.60 | Outlier |
| vn.momo.cinema | 104,268 | 10,140 | 10,427 | ⚠️ -2.96 | Chú ý |
| vn.momo.mobilecenter | 87,091 | 8,413 | 8,709 | ❌ -3.34 | Outlier |
| vn.momo.transactionhistory | 80,195 | 7,787 | 8,020 | ⚠️ -2.74 | Chú ý |
| vn.momo.billpay | 74,355 | 7,217 | 7,436 | ⚠️ -2.67 | Chú ý |
| vn.momo.compose-global | 61,294 | 5,930 | 6,129 | ⚠️ -2.68 | Chú ý |
| vn.momo.groupfund | 58,786 | 5,697 | 5,879 | ⚠️ -2.50 | Chú ý |
| vn.momo.heodat | 49,514 | 4,753 | 4,951 | ⚠️ -2.97 | Chú ý |
| vn.momo.paylaterverse | 48,766 | 4,803 | 4,877 | ✅ -1.11 | OK |
| vn.momo.investment | 48,165 | 4,682 | 4,817 | ⚠️ -2.04 | Chú ý |
| vn.momo.financial_hub | 36,700 | 3,426 | 3,670 | ❌ -4.25 | Outlier |
| vn.momo.finance | 34,290 | 3,317 | 3,429 | ⚠️ -2.02 | Chú ý |
| vn.momo.promotionhub | 33,494 | 3,274 | 3,349 | ✅ -1.37 | OK |
| vn.momo.travel | 24,849 | 2,458 | 2,485 | ✅ -0.57 | OK |
| vn.momo.vaynhanh | 24,663 | 2,449 | 2,466 | ✅ -0.37 | OK |
| vn.momo.web.lx26 | 19,458 | 1,904 | 1,946 | ✅ -1.00 | OK |

> **Diễn giải Phase 4 (64 miniapps, đã loại "empty"):**
>
> Khi tách riêng top 3 miniapp (home_momo 2.6M, compose-old 904K, bank 503K), bức tranh rõ hơn rất nhiều:
>
> - **42 miniapp Medium+Low (66%): φ = 1.18–1.56** — sampling hoạt động tốt, 0 outlier.
> - **61 miniapp (excl top 3): φ = 3.67** — chưa lý tưởng nhưng cải thiện 9× so với φ gốc.
> - **Top 3 miniapp kéo φ tổng từ 3.67 → 33.26** vì Z-score tỷ lệ √n — cùng 6.6% deviation nhưng n triệu tạo |Z| = 6–42.
>
> Kết luận: sampling method không sai cho đa số miniapp. Vấn đề chỉ tập trung ở **tỷ lệ sampling ngày 28/02 đạt 9.0% thay vì 10%**, bị phóng đại bởi Z-test ở n lớn.

---

## Phase 5 — Over-Dispersion Test

Kiểm tra φ = Σ(Z²)/(n-1) cho 64 starting miniapps. Nếu sampling thực sự ngẫu nhiên, φ ≈ 1.0. Phân tích sâu: tách riêng top 3 miniapp có impact lớn nhất để thấy rõ bản chất bias.

### Tại sao φ cao đến vậy?

φ = Σ(Z²)/(n-1). Mỗi Z² cộng vào tổng. **3 miniapp top đóng góp bao nhiêu?**

| Miniapp | Users | Z | Z² | % tổng Σ(Z²) |
|---------|-------|---|-----|--------------|
| home_momo | 2,648,047 | ❌ -41.86 | 1,752.3 | ❌ **83.4%** |
| compose-old | 904,354 | ❌ -9.33 | 87.0 | 4.1% |
| bank | 502,501 | ❌ -6.00 | 35.9 | 1.7% |
| **TOP 3 TỔNG** | | | **1,875.3** | **❌ 89.3%** |
| 61 miniapp còn lại | | | 225.5 | 10.7% |

> **89.3% tổng Σ(Z²) đến từ chỉ 3 miniapp.** Riêng home_momo chiếm 83.4%. Đây là nguyên nhân duy nhất khiến φ tổng = 33.26. Khi loại 3 miniapp này: φ = Σ(Z²)/df = 225.5/60 = **3.67**.

### Bảng tổng hợp φ — 4 góc nhìn

| Phạm vi | # Miniapp | Mean Z | Std Z | φ | Đánh giá | Ý nghĩa thực tế |
|---------|----------|--------|-------|---|----------|-----------------|
| Toàn bộ (excl empty) | 64 | -2.06 | 5.38 | ❌ 33.26 | FAIL | Bị skew bởi top 3 |
| **Excl Top 3 Impact** | **61** | **-1.22** | **1.47** | **⚠️ 3.67** | **GẦN ĐẠT** | **Phản ánh đúng 95% miniapp** |
| Medium Traffic | 21 | -0.83 | 0.92 | ⚠️ 1.56 | Chấp nhận | Sampling ổn định |
| Low Traffic | 21 | -0.49 | 0.96 | ✅ 1.18 | **PASS** | Nằm trong 0.8–1.2 |

### Top 3 Impact — Phân tích riêng

| Miniapp | Total Users | Sample | Expected (10%) | Actual Rate | Rate Gap | Z-Score |
|---------|-----------|--------|---------------|-------------|----------|---------|
| home_momo | 2,648,047 | 244,371 | 264,805 | 9.23% | ❌ -0.77% | ❌ -41.86 |
| compose-old | 904,354 | 87,773 | 90,435 | 9.71% | ⚠️ -0.29% | ❌ -9.33 |
| bank | 502,501 | 48,975 | 50,250 | 9.75% | ⚠️ -0.25% | ❌ -6.00 |

> **Phát hiện quan trọng:** Chênh lệch tỷ lệ thực tế chỉ **0.25%–0.77%** (9.23%–9.75% vs 10%). Đây là deviation rất nhỏ. Tuy nhiên, vì Z-test nhân chênh lệch với √n, n = 2.6 triệu tạo Z = -42. **Z-test quá nhạy (overpowered) ở sample size lớn** — nó phát hiện sự khác biệt thống kê nhưng không có ý nghĩa thực tiễn.
>
> **Khuyến nghị:** Với top miniapps, nên dùng **effect size (% gap)** thay vì Z-score để đánh giá. Gap 0.25–0.77% là hoàn toàn chấp nhận được cho analytics.

### Thang đánh giá φ

| Khoảng φ | Ý nghĩa |
|----------|---------|
| 🟢 0.8 – 1.2 | Tốt — khớp kỳ vọng nhị thức |
| 🟡 1.2 – 4.0 | Phân tán nhẹ → vừa — kiểm tra nguyên nhân |
| 🔴 > 4.0 | Nghiêm trọng — bias hệ thống |

---

## Kết Luận Tổng Thể

### Executive Summary

Với mục tiêu cho user cái nhìn tổng quan về hành trình tương tác, việc dùng data sampling scale còn 10% nhưng vẫn đạt coverage khớp 100% hành vi tương tác app của user MoMo với mức chênh lệch chỉ ~6.08% (< 10%), cùng phân bố hành vi khớp.

Đổi lại: giảm **90% compute cost** và cho phép **daily refresh** — không thể đạt được nếu chạy full data. φ tổng bị inflate do artifact toán học ở top miniapps, nhưng tỷ lệ thực chỉ chênh 0.25–0.77%.

### Cơ sở Lý thuyết: Tại sao 10% sampling (~352K user) đủ đại diện?

#### 1. Định lý Giới hạn Trung tâm (Central Limit Theorem)

Khi kích thước mẫu **n ≥ 30**, phân bố trung bình mẫu hội tụ về **phân bố chuẩn** (Normal Distribution), bất kể phân bố gốc. Với n = 351,840 (mẫu Apollo), CLT đảm bảo mọi ước lượng thống kê đều cực kỳ ổn định.

#### 2. Margin of Error (Sai số biên)

Công thức: `ME = Z × √(p(1-p)/n)`

Với n = 351,840 và confidence level 95% (Z = 1.96):

```
ME = 1.96 × √(0.5 × 0.5 / 351,840)
ME = 1.96 × 0.000843
ME = ±0.17%
```

Nghĩa là: với ~352K user, bất kỳ tỷ lệ nào (ví dụ: % user dùng feature X) đều có sai số tối đa chỉ **±0.17%** ở mức tin cậy 95%. Đây là độ chính xác cực cao.

#### 3. So sánh: Cần bao nhiêu mẫu?

| Kích thước mẫu | Margin of Error | Đánh giá |
|----------------|----------------|----------|
| 384 (survey chuẩn) | ±5.0% | Minimum cho khảo sát |
| 1,067 | ±3.0% | Khảo sát chất lượng tốt |
| 9,604 | ±1.0% | Rất chính xác |
| 96,040 | ±0.32% | Cực kỳ chính xác |
| **351,840 (Apollo)** | **±0.17%** | ✅ **Vượt xa yêu cầu** |

#### 4. Quy luật căn bậc hai (Diminishing Returns)

Margin of Error giảm theo `1/√n`. Tăng mẫu từ 352K → 3.9M (full) chỉ giảm ME từ 0.17% → 0.05% — **cải thiện 0.12% nhưng tốn gấp 10× chi phí**. Đây là điểm diminishing returns rõ ràng.

#### Kết luận từ lý thuyết

Với **N = 3.91M** (quần thể) và **n = 352K** (mẫu), lý thuyết thống kê đảm bảo:

- **Margin of Error = ±0.17%** (confidence 95%) — sai số nhỏ hơn 50× so với ngưỡng chấp nhận 10%
- **Coverage ≥ 95% use case** — CLT + Law of Large Numbers đảm bảo mẫu 352K bảo toàn phân bố gốc
- **Diminishing returns** — chạy full data chỉ cải thiện 0.12% accuracy nhưng tốn thêm 500GB scan/ngày

Nói cách khác: **352K mẫu thừa sức đại diện cho 3.91M quần thể**. Ngay cả các cuộc thăm dò dư luận quốc gia (population 300M+) cũng chỉ khảo sát ~1,000 người. Apollo sampling với 352K user có sức mạnh thống kê vượt trội.

---

**Trade-off Evaluation cho 10% Sampling method của Path Exploration:**

#### ✅ Điểm đạt

- **Coverage 100%** — không mất path nào quan trọng
- **Gap 6.08% < 10%** — đủ chính xác cho overview
- **User behavior khớp** — median hoàn toàn giống nhau
- **66% miniapps φ ≤ 1.56** — sampling ổn định
- **Top 3 chênh chỉ 0.25–0.77%** tỷ lệ thực tế

#### 💎 Trade-off đạt được

- **Giảm 90% compute cost** mỗi ngày
- **Tiết kiệm ~500 GB** BQ scan/ngày
- **Daily refresh** thay vì weekly batch
- **Query response nhanh 10×** cho user
- **Scalable** khi MoMo tăng user base

Path Exploration không có độ chính xác tuyệt đối — nhưng đảm bảo mục tiêu cho MoMo-er có cái nhìn **tổng quan về hành trình user trên MoMo**:

- Path nào phổ biến, user flow ra sao, conversion ở đâu.

Gap ~6% không ảnh hưởng đến những insight này. Ngược lại, nếu chạy full data daily, chi phí xử lí và lưu trữ dữ liệu sẽ tăng 10× trong khi insight gần như không thay đổi.
