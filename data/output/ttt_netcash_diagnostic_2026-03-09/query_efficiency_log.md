# Query Efficiency Log — TTT Net Cash Diagnostic
> Ngày chạy: 2026-03-11 | Project: momovn-bu-fi-shared | Table: momovn-prod.BU_FI.mart_ttt_daily_user_record

## Tổng Quan
| Metric | Value |
|--------|-------|
| Tổng số queries | 16 |
| Tổng GB scanned | ~2,956 GB |
| Tổng thời gian | ~58 phút |
| Target per query | < 200 GB |
| Queries vượt 200 GB | 6/16 (38%) |

## Chi Tiết Từng Query

| # | Query | GB Scanned | Duration | Rows | Vượt 200GB? | Ghi chú |
|---|-------|-----------|----------|------|-------------|---------|
| Q1 | monthly_netcash | 699.3 | ~5:00 | 15 | **YES** | Full table scan 15 tháng |
| Q1b | monthly_netcash_by_type | 728.6 | ~3:30 | 64 | **YES** | + TYPE column GROUP BY |
| Q2 | cashout_breakdown | 699.3 | ~5:00 | 15 | **YES** | Full table scan, 7 CO columns |
| Q3 | cashin_breakdown | 699.3 | ~5:00 | 15 | **YES** | Full table scan, 8 CI columns |
| Q4 | daily_march_comparison | 26.9 | 0:01 | 9 | No | Chỉ 2 tháng March |
| Q4b | daily_march_by_type | 17.7 | 0:08 | 36 | No | March 2026 only |
| Q5 | aum | 4.9 | 0:02 | 15 | No | End-of-month snapshots |
| Q5b | aum_by_type | 2.6 | 0:06 | 24 | No | 6 months × 4 types |
| Q6 | mau_mfu | 194.5 | 2:17 | 15 | No | REGEXP_EXTRACT heavy |
| Q7 | march_cashout_detail | 21.1 | 0:03 | 2 | No | 2 months March only |
| Q7b | march_cashout_by_type | 10.1 | 0:07 | 4 | No | March 2026 × 4 types |
| Q8 | balance_groups | 3.2 | 0:01 | 8 | No | 8 snapshot dates |
| Q9 | weekly_netcash | 131.4 | 0:44 | 11 | No | ~11 weeks only |
| Q10 | mfu_churn | 699.3 | ~5:00 | 15 | **YES** | GRASS_DATE = LAST_DAY filter |
| Q11 | per_user | 699.3 | ~0:50 | 9 | **YES** | 9 selected months |
| Q12 | tttplus_tier_netcash | 695.5 | 0:38 | 27 | **YES** | Full TTT+ table scan |
| Q13 | tttplus_segment_march | 30.9 | 0:01 | 9 | No | March only |

## Top Resource-Heavy Queries (cần tối ưu)

### 1. Q1b: monthly_netcash_by_type — 728.6 GB
```sql
-- Nguyên nhân: Full table scan toàn bộ 15 tháng, tính SUM trên 15 columns
-- Giải pháp tiềm năng:
-- 1. Sử dụng cột netcash đã pre-computed thay vì tính lại
-- 2. Partition pruning: Nếu table partition by GRASS_DATE sẽ giảm xuống ~47 GB/tháng
-- 3. Tách thành 2 queries: 2025 riêng, 2026 riêng
```

### 2. Q1/Q2/Q3: monthly_netcash/cashout/cashin — 699.3 GB mỗi query
```sql
-- Nguyên nhân: Tương tự Q1b, scan toàn bộ table cho GROUP BY tháng
-- Giải pháp: Merge Q1 + Q2 + Q3 thành 1 query duy nhất
-- → Tiết kiệm ~1,400 GB (3 queries → 1 query ~700 GB)
```

### 3. Q10: mfu_churn — 699.3 GB
```sql
-- Nguyên nhân: GRASS_DATE = LAST_DAY(GRASS_DATE) filter KHÔNG pruning partition
-- BigQuery phải scan TOÀN BỘ table rồi mới filter
-- Giải pháp: Liệt kê explicit dates IN (...) giống Q5/Q8
-- → Giảm từ 699 GB xuống ~5 GB
```

### 4. Q12: tttplus_tier_netcash — 695.5 GB
```sql
-- Nguyên nhân: WHERE TYPE = 'TTT+' không partition pruning
-- Phải scan toàn bộ 15 tháng mặc dù chỉ cần TTT+ rows
-- Giải pháp: Nếu table partition by GRASS_DATE, chỉ cần scan relevant months
```

## Đề Xuất Tối Ưu

1. **Merge Q1+Q2+Q3** thành 1 query lớn → tiết kiệm ~1,400 GB
2. **Dùng cột `netcash` pre-computed** cho Q1/Q1b → bỏ 15 columns tính toán
3. **Q10: Explicit date list** thay vì LAST_DAY filter → giảm 699 GB → 5 GB
4. **Q6 MAU/MFU**: REGEXP_EXTRACT rất tốn CPU. Nếu USER_ID đã clean, có thể bỏ
5. **Target**: Với tối ưu trên, tổng GB có thể giảm từ ~2,956 GB xuống ~1,200 GB (-60%)
