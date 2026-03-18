# Knowledge: Tui Than Tai (TTT)
> Learned gotchas, corrections, business insights. Never auto-overwritten.
> Last updated: 2026-03-04

## SQL Gotchas

### Always Filter by MAU_TYPE or MFU_TYPE (2026-03-02)
Table stores ALL users including churned. Without filter, COUNT(DISTINCT USER_ID) = ~11M (total ever), not active.

| Metric | Filter | Jan 2026 |
|--------|--------|----------|
| Total accounts | None | 11.1M |
| MFU (funded) | `MFU_TYPE != '0.Churn'` | 1.67M |
| MAU (active) | `MAU_TYPE != '0.Churn'` | 3.46M (Individual 3.0M + Money Pool 463K) |

### Correct MAU Query Pattern (2026-03-02)
Use full month date range (NOT end-of-month snapshot), REGEXP_EXTRACT for USER_ID dedup, GROUP BY IS_MP:
```sql
SELECT t1.IS_MP,
    COUNT(DISTINCT (CAST(REGEXP_EXTRACT(t1.USER_ID, r'\d+') AS STRING))) AS unique_mau_users
FROM momovn-prod.BU_FI.mart_ttt_daily_user_record AS t1
WHERE t1.GRASS_DATE BETWEEN '2026-01-01' AND '2026-01-31'
    AND t1.MAU_TYPE != '0.Churn'
GROUP BY t1.IS_MP
```

Mistakes to avoid:
- Do NOT use single end-of-month snapshot
- Do NOT use raw USER_ID — always REGEXP_EXTRACT for dedup
- Group by IS_MP to separate Individual vs Money Pool

### MAU_TYPE vs MFU_TYPE: Different Metrics! (2026-03-02)
- **MAU_TYPE**: Monthly Active Users — anyone who used/visited TTT
- **MFU_TYPE**: Monthly Funded Users — anyone who has money in TTT
- Example: Dec 2025 Retain — MAU=2.79M, MFU=2.49M
- Churn pool is massive: ~12.2M churned vs ~3.7M active

### Include Money Pool in MAU (2026-03-02)
Always GROUP BY IS_MP. Individual ~3.0M + Money Pool ~463K = Total 3.46M (not just 3.0M).

### USER_ID Dedup: Context Matters (2026-03-02)
- **Total unique humans:** Use REGEXP_EXTRACT — same person can appear as both Individual and Money Pool
- **Per-IS_MP:** Raw user_id (higher, counts accounts) or REGEXP_EXTRACT (lower, counts humans)

### AUM: End-of-Month Snapshot, NOT Sum Across Days (2026-03-03)
**Mimir gets AUM wrong** — sums BALANCE across all days (~30x inflation).
```sql
-- CORRECT: end-of-month snapshot
WHERE GRASS_DATE = LAST_DAY(DATE '2025-01-01')
```
Jan 2026 AUM: Individual 9.95T + Money Pool 1.62T = **11.57T VND total**

### AUM: Do NOT Filter by MFU_TYPE (2026-03-03)
AUM measures total balance across ALL accounts, including churned (may still hold balances).
- AUM query: NO MFU_TYPE filter
- MAU query: `MAU_TYPE != '0.Churn'`
- MFU query: `MFU_TYPE != '0.Churn'`

### Cashin/Cashout: Sum ALL Sub-Channel Columns (2026-03-03)
`cashin_gmv` is NOT total — it's one sub-channel. Must sum all:
**Cashin:** `cashin_gmv` + `cashin_p2p_gmv` + `cashin_va_gmv` + `cashin_ai_gmv` + `cashin_stock_gmv` + `cashin_payout_gmv`
**Cashout:** `cashout_gmv` + `cashout_napas_gmv` + `cashout_payment_gmv` + `cashout_stock_gmv` + `cashout_p2p_gmv` + `cashout_mp_gmv` + `cashout_payment_mp_gmv`
Always COALESCE(col, 0). Using just `cashin_gmv` = ~50% of actual.

### Pre-computed `netcash` Column (2026-03-11)
Table now has a `netcash` column = total cashin - total cashout (pre-computed).
**Use `SUM(netcash)` instead of the long formula.** Still need individual sub-channel columns for breakdowns.

### Luôn lấy data tới MTD (2026-03-12)
**KHÔNG hardcode ngày cuối.** Luôn dùng `CURRENT_DATE('+7') - 1` (hôm qua, timezone VN) làm upper bound.
```sql
-- ĐÚNG: lấy tới ngày gần nhất có data
WHERE GRASS_DATE BETWEEN '2025-09-01' AND DATE_SUB(CURRENT_DATE('+7'), INTERVAL 1 DAY)

-- SAI: hardcode ngày
WHERE GRASS_DATE BETWEEN '2025-09-01' AND '2026-02-28'
```
MTD = Month-To-Date. Data TTT lag 1 ngày (hôm nay chưa có, hôm qua mới nhất).

### Column Names (2026-03-03)
- Interest: `interest` (NOT `interest_gmv`)
- Balance: `balance` (NOT `saving_balance`)
- Average balance: `avg_balance`

## Business Insights

### Interest Column = Paid to Users (MoMo's Cost) (2026-03-04)
`interest` = interest credited to users per day. Jan 2026: ~1,049M/day Individual + 172M/day Money Pool.
Monthly: ~37.95B paid to savers. This is MoMo's cost, NOT income.
MoMo's TTT income = 11.57T AUM × 6% / 12 = 57.9B gross - 37.95B = ~20B net spread.

### Money Pool: Cohort Deepening Pattern (2026-03-04)
Jan 2025 cohort: start 77.5K users × 1.95M avg → 14m later 71K users × 3.65M avg (+87% balance growth).
User attrition -8.4%. Weak savers churn months 1-3, power savers remain and compound.

### Unfunded Users: 53% Ever-Funded vs 47% Never-Funded (2026-03-04)
Of 1.17M unfunded Individual MAU: 623K (53%) = previously funded (reactivation 3-5× easier), 548K (47%) = never funded.

### Chi phí Túi+ đầy đủ gồm 3 thành phần (2026-03-12)
Khi nói "chi phí Túi+", phải tính ĐỦ 3 loại:

| # | Chi phí | Column | Quy đổi VND | Mô tả |
|---|---------|--------|-------------|-------|
| 1 | **Cashback 0.1%** | `TOTAL_CASHBACK_GMV` | Đã là VND | Hoàn tiền khi user Túi+ thanh toán bằng TTT |
| 2 | **Xu sinh lời (Coin Interest)** | `COIN_INTEREST` | `COIN_INTEREST / 2` | User Túi+ được sinh lời 8%/năm với xu MoMo |
| 3 | **Xu SOF (Coin SOF)** | `COIN_SOF` | `COIN_SOF / 2` | Xu thưởng khi user Túi+ thanh toán hóa đơn/dịch vụ bằng nguồn tiền TTT |

**Menh giá quy đổi: 2 xu MoMo = 1 VND**

Tổng chi phí VND = `TOTAL_CASHBACK_GMV + COIN_INTEREST/2 + COIN_SOF/2`

Columns phân loại (dùng để COUNT user):
- `IS_COIN_INT`: user có nhận xu sinh lời hay không
- `IS_COIN_SOF`: user có nhận xu SOF hay không
- `IS_CASHBACK`: user có nhận cashback hay không

### Doanh thu Túi+ = Subscription + Bundle (2026-03-12)
- **Subscription**: Phí mua tier hàng tháng. Pre-2026: 9K flat. Post-2026: Silver=9K, Gold=19K, Platinum=49K. Upgrade chỉ trả chênh lệch (trong cùng tháng).
- **Bundle voucher**: `PACKAGE_GMV` — doanh thu riêng từ bán gói voucher.
- Detect subscription từ `PLUS_SEGMENT LIKE '%Buy%'` kết hợp daily LAG(TIER) để tính upgrade pricing.

## Mimir Trust
- MAU/MFU: HIGH (exact match Feb 2026, correct REGEXP_EXTRACT + MAU_TYPE filter)
- AUM: HIGH (bug FIXED as of 2026-03-06 — Mimir now uses end-of-month snapshot, not sum across days)
- General: HIGH
- Feb 29 bug: persists but Mimir self-corrects with retry
