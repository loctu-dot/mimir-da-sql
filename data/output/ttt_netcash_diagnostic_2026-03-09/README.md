# TTT Net Cash Diagnostic — Tháng 3/2026 (v2 — Updated)

## Bối cảnh
Tháng 3/2026 MTD (9 ngày, 8 ngày giao dịch), Túi Thần Tài ghi nhận net cash âm **-209 tỷ VND**. Báo cáo này phân tích nguyên nhân gốc rễ với dữ liệu sau re-ETL (10/03/2026).

## Phát hiện cốt lõi
1. **TTT+ là driver chính:** -218 tỷ (104% tổng drain). TTT regular vẫn dương +24 tỷ.
2. **Platinum tier (48K users, <1%)** chiếm 80% drain TTT+. Balance 50M+ segment = 76%.
3. **Structural issue:** TTT+ luôn âm mọi tháng — không phải bất thường T3.
4. **Market factors:** Lãi suất bank 7-8% vs TTT 4%, vàng ATH, CPI cao, VN-Index giảm.

## Files
| File | Nội dung |
|------|---------|
| `01_query_results.md` | Kết quả 16 SQL queries (bao gồm TYPE/TIER/SEGMENT breakdown) |
| `02_insights.md` | Phân tích chẩn đoán + thống kê + tâm lý học hành vi |
| `03_dashboard.html` | **SPA Dashboard 9 tabs** — mở trong browser (MoMo pink theme, tiếng Việt có dấu) |
| `stat_analysis.py` | Script Python kiểm định thống kê v2.0 (n=365 baseline, Welch t, Mann-Whitney U, Cohen's d) |
| `query_efficiency_log.md` | Log hiệu suất query (GB scan, thời gian, đề xuất tối ưu) |
| `sql/` | 17 file SQL queries (bao gồm q14 daily stats full year) |
| `results/` | Raw CSV results từ BigQuery (bao gồm q14 433 ngày daily data) |

## Cách xem
```
# Mở dashboard
start 03_dashboard.html

# Chạy thống kê
python stat_analysis.py
```

## Thay đổi so với v1
- Dữ liệu sau re-ETL (10/03): Net cash T3 = -209 tỷ (v1: -416 tỷ)
- **MỚI:** Phân tích theo TYPE (TTT, TTT+, Quỹ Nhóm, Merchant)
- **MỚI:** TTT+ deep dive theo TIER (Silver/Gold/Platinum) và PLUS_SEGMENT
- **MỚI:** Tâm lý học hành vi kinh tế (Loss Aversion, Herding, Mental Accounting...)
- **MỚI:** Query efficiency log
- Thêm ngày 9/3 (9 ngày MTD thay vì 8)
- Dashboard nâng lên 8 tabs (từ 7)
- Formulas và logic giải thích transparent

## v3 — Thay đổi (11/03/2026)
- **MỚI:** Dashboard chuyển sang MoMo pink theme + tiếng Việt có dấu toàn bộ
- **MỚI:** Tab 6 kiểm định thống kê v2.0 — baseline n=365 ngày (thay vì n=12 tháng)
  - Welch t-test, Mann-Whitney U (phi tham số), One-sample t, Cohen's d effect size
  - Query q14: 433 ngày daily data (597GB scanned)
  - Phân tích chi tiết: Net Cash, CO/CI, CO P2P, CI vs CO asymmetry, trend analysis
- **MỚI:** Tab 9 "Chiến Lược & Đề Xuất" — 8 suggestions xếp hạng P0→P3
  - Mỗi suggestion có: bằng chứng từ report, benchmark ngành (GCash, Nubank, Toss, Revolut, SoFi...), impact định lượng
  - Bảng tổng hợp ranking theo Root Cause × Tốc độ × ROI
- `stat_analysis.py` v2.0 — đọc CSV daily data, 6 tests, kết luận tiếng Việt có dấu
