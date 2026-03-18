# PR #1 Update — Schema Inspection Optimization

> **Branch:** `pr/loctu-contributions-2026-03-18`
> **Author:** Loc Tu (loc.tu@mservice.com.vn)
> **Date:** 2026-03-18
> **Scope:** `docs/DA_PROMPT.md` — 1 file changed

---

## Tổng quan

Cập nhật approach kiểm tra schema bảng trong DA workflow: thay vì `SELECT * ... LIMIT` (tốn resource do full table scan), dùng `INFORMATION_SCHEMA.COLUMNS` để lấy metadata trước, rồi mới sample data có filter theo partition column.

---

## Thay đổi chi tiết

### 1. Step 2 (Schema unclear) — Thay đổi lớn

**Trước:** `SELECT * FROM <table> LIMIT 1` để xem column names

**Sau:**
- Query `INFORMATION_SCHEMA.COLUMNS` để lấy `column_name`, `data_type`, `is_partitioning_column` — **zero data scan cost**
- Nếu có partition column → dùng nó filter (D-1 hoặc đầu tháng) + `LIMIT 10`
- Nếu không có partition column → `SELECT * LIMIT 10` chấp nhận được, nhưng **phải cảnh báo user về resource cost**

### 2. Undocumented columns — MANDATORY discovery step (Mới)

Thêm quy trình bắt buộc khi phát hiện column không có metadata mô tả:
- Query `SELECT DISTINCT <unknown_column>` trong 1 ngày (filter partition nếu có)
- Show distinct values cho user
- Yêu cầu user cung cấp ý nghĩa column (lưu vào `lt-memory/knowledge/`) hoặc escalate lên Data Owner
- **Không được đoán** column semantics khi chưa hiểu

### 3. Domain Discovery section — Update steps

- Step 2: Probe schema first (INFORMATION_SCHEMA)
- Step 3: Sample actual rows (có partition filter, warn resource cost nếu không có partition)
- Step 4 (mới): Discover undocumented columns → show user → ask clarification/escalation
- Step 5: Record everything

---

## Lý do thay đổi

- `SELECT * LIMIT N` trên bảng có partition vẫn trigger full table scan → **tốn hàng GB data processed** trên BigQuery (tính tiền theo bytes scanned)
- `INFORMATION_SCHEMA.COLUMNS` hoàn toàn miễn phí, cho đầy đủ thông tin schema
- Column không có metadata mô tả dễ dẫn đến phân tích sai nếu đoán sai ý nghĩa → cần mandatory discovery step
