# Material Git Client — Design Specification

> Hệ thống thiết kế cho ứng dụng Git desktop, xây dựng trên **Material 3 (Material You)**.
> Nền sáng · Accent Google Blue `#1A73E8` · 3 style variants · 3 mức mật độ.

| Thuộc tính | Giá trị |
|---|---|
| Design language | Material 3 (Material You) |
| Theme | Light |
| Accent / Primary | `#1A73E8` (Google Blue) |
| Typeface | Roboto (UI) · Roboto Mono (mã, hash, số liệu) |
| Iconography | Material Symbols Rounded |
| Variants | Clean · Tonal · Outlined |
| Density | Compact · Regular · Comfy |

---

## 01 · Overview & principles

Bốn nguyên tắc dẫn dắt toàn bộ quyết định thị giác:

- **Tonal surfaces** — Phân cấp độ sâu bằng các lớp *surface container* (lowest → highest) thay vì đổ bóng nặng. Bóng chỉ dùng tinh tế ở mức elevation 1–3.
- **State layers & ripple** — Mọi phần tử tương tác có lớp trạng thái phủ (hover 6–8%, pressed 11–12%) và hiệu ứng *ripple* lan từ điểm chạm — phản hồi đặc trưng Material.
- **Soft geometry** — Bo góc rộng và nhất quán theo thang shape. Nút dạng viên thuốc (pill), ô tìm kiếm bo tròn hoàn toàn, thẻ bo 12–16px.
- **Purposeful color** — Màu accent chỉ dành cho hành động chính và trạng thái chọn. Màu git (added / removed / modified) mã hoá ngữ nghĩa, không trang trí.

---

## 02 · Color tokens

Bảng màu sinh ra từ một accent duy nhất (tweakable) + thang neutral hơi ám lạnh + màu ngữ nghĩa cho Git.

### Accent & tonal derivations

| Token | Giá trị | Vai trò |
|---|---|---|
| Accent / Primary | `#1A73E8` | Nút chính, link, chỉ báo tab, viền focus |
| Accent container | `accent 13% + white` | Chip branch, item được chọn, nút tonal |
| On accent container | `accent 62% + ink` | Chữ/icon trên nền accent container |
| State layer | `accent 8% / 12%` | Hover & pressed của hành động accent |

### Neutral surfaces (light)

| Token | Hex | Vai trò |
|---|---|---|
| `--surface` | `#FCFCFF` | Nền chính của vùng làm việc |
| `--sc-lowest` | `#FFFFFF` | Ô nhập, checkbox |
| `--sc-low` | `#F6F7FB` | Thẻ danh sách file, header |
| `--sc` | `#F0F2F7` | Nền sidebar (rail) |
| `--sc-high` | `#EAECF2` | Ô tìm kiếm, count pill |
| `--sc-highest` | `#E4E6EC` | Icon container trung tính |
| `--on-surface` | `#1A1C1F` | Chữ chính |
| `--on-surface-variant` | `#44474E` | Chữ phụ, icon |
| `--on-surface-faint` | `#74777F` | Placeholder, metadata |
| `--outline-variant` | `#C4C6CF` | Viền nút outlined, đường kẻ đậm |
| `--outline-faint` | `#E2E3EA` | Đường phân cách nhẹ |

### Git semantic colors

| Trạng thái | Foreground | Background | Áp dụng |
|---|---|---|---|
| Added | `#1E8E3E` | `#E6F4EA` | Dòng thêm, +count, stage |
| Removed | `#D93025` | `#FCE8E6` | Dòng xoá, −count, delete |
| Modified | `#E37400` | `#FEEFC3` | File sửa, badge "M", behind |
| Renamed | `#8430CE` | `#F3E8FF` | File đổi tên / di chuyển |

---

## 03 · Typography

**Roboto** cho giao diện · **Roboto Mono** cho mã, hash, số liệu diff. Thang chữ gọn, dày dặn ở weight 500.

| Vai trò | Size | Weight | Tracking | Ví dụ |
|---|---|---|---|---|
| Title / Large | 40px | 500 | −0.5 | Material Git Client |
| Headline | 25px | 500 | — | Staged changes |
| Title | 15px | 600 | — | Toolbar.jsx |
| Body | 13–14px | 400 | — | Select a changed file to preview its diff. |
| Label | 11–13px | 500 | — | Commit · Pull · Push |
| Overline | 11px | 700 | +0.8 · UPPER | UNSTAGED CHANGES |
| Mono | 11–12px | 400/500 | — | `a1b2c3d  +13 −5` |

---

## 04 · Shape & elevation

### Corner radius scale

| Token | Giá trị | Áp dụng |
|---|---|---|
| `--r-xs` | 8px | Snackbar, status badge |
| `--r-sm` / card | 12px | Thẻ, nút trên toolbar |
| `--r-md` | 16px | Thẻ (variant Tonal) |
| `--r-btn` | 20px / full | Nút, chip, ô tìm kiếm |

### Elevation

| Level | Token | Áp dụng |
|---|---|---|
| Level 1 | `--e1` | Thẻ, nút filled mặc định |
| Level 2 | `--e2` | Nút filled khi hover |
| Level 3 | `--e3` | Snackbar, menu nổi |

---

## 05 · Spacing & density

Đơn vị cơ sở **4px**. Hệ số mật độ `--d` co giãn padding & cỡ chữ theo 3 mức.

| Mật độ | Hệ số `--d` | Cỡ chữ nền | Áp dụng |
|---|---|---|---|
| Compact | 0.82 | 13px | Màn hình nhỏ, nhiều file — xem được nhiều dòng hơn |
| **Regular** *(mặc định)* | 1.00 | 14px | Cân bằng thoải mái cho đa số tác vụ |
| Comfy | 1.16 | 15px | Khoảng thở rộng, dễ đọc, màn hình lớn |

> **Lưu ý:** Khoảng cách trong component (padding hàng, section) nhân với `--d`; khoảng cách cấu trúc (viền, đường kẻ) giữ cố định để bố cục không vỡ.

---

## 06 · Iconography

**Material Symbols Rounded** — bo tròn, weight 400, opsz 24. Fill 0 cho trạng thái thường, Fill 1 khi được chọn.

| Icon | Glyph | Dùng cho |
|---|---|---|
| commit | `commit` | Commit |
| pull | `arrow_cool_down` | Pull |
| push | `arrow_warm_up` | Push |
| fetch | `sync` | Fetch |
| branch | `account_tree` | Branch |
| merge | `merge` | Merge |
| stash | `inventory_2` | Stash |
| repo | `folder_open` | Repository |
| terminal | `terminal` | Terminal |
| tag | `sell` (fill 1) | Tag |

---

## 07 · Components

### Buttons

| Loại | Style | Quy tắc dùng |
|---|---|---|
| **Filled** | Nền accent, chữ trắng | Duy nhất một hành động chính mỗi vùng (Commit). Tự disable khi chưa đủ điều kiện. |
| **Tonal** | Nền accent container | Hành động phụ nổi bật (Stage file). |
| **Outlined** | Viền 1px | Hành động ngang hàng, ít nhấn (Stage all). |
| **Text** | Chỉ chữ accent | Hành động nhẹ trong tiêu đề section. |

### Toolbar actions & fields

- **Toolbar action** — icon container tròn 40px (hành động chính) hoặc icon trần 23px + nhãn 11px bên dưới.
- **Search field** — bo tròn hoàn toàn (`--r-full`), nền `--sc-high`, viền accent khi focus.
- **Filter field** — nền `--sc-low` + viền `--outline-variant`.

### File rows & status badges

- Hàng file: checkbox stage · status badge · tên file · thư mục (mờ) · +/− count (mono, phải).
- Hàng được chọn: nền **accent container**.
- Badge trạng thái: **M** modified · **A** added · **D** deleted · **R** renamed.

---

## 08 · Diff & status

Diff hai cột số dòng (cũ / mới), nền ngữ nghĩa, hunk header tô accent.

```
@@ -12,9 +12,14 @@ export function Toolbar()      ← hunk header (nền accent 8%)
 12  12    const actions = [
 13      −    { icon: 'commit', label: 'Commit' },        ← del (nền #FCE8E6)
     13  +    { icon: 'commit', label: 'Commit', primary: true },   ← add (nền #E6F4EA)
     14  +    { icon: 'pull', label: 'Pull' },
```

- Cột số dòng: 2 cột (old / new), mỗi cột 42px, căn phải.
- Dòng thêm: nền `#E6F4EA`, chữ `#0B5B27`, dấu `+`.
- Dòng xoá: nền `#FCE8E6`, chữ `#A50E0E`, dấu `−`.
- Hunk header: nền accent 8%, chữ accent.

---

## 09 · Style variants

Cùng một bố cục, ba tính cách thị giác — chuyển trong bảng **Tweaks**.

| Variant | Mô tả | Đặc trưng |
|---|---|---|
| **Clean** *(mặc định)* | M3 trung tính: bề mặt trắng/xám nhạt, bóng tinh tế, bo 12px. An toàn, rõ ràng, chuyên nghiệp. | Neutral · Subtle shadow · 12px |
| **Tonal** | Material You biểu cảm: bề mặt ám màu accent, bo 16px, nút dạng viên thuốc. Ấm áp, có cá tính. | Accent-tinted · Pill buttons · 16px |
| **Outlined** | Phẳng & sắc: không bóng, mọi thẻ dùng viền 1px. Gọn gàng, lý tưởng cho power-user. | Flat · 1px borders · No shadow |

### Accent options

| Màu | Hex |
|---|---|
| Blue *(mặc định)* | `#1A73E8` |
| Purple | `#6750A4` |
| Teal | `#00897B` |
| Orange | `#E8710A` |
| Red | `#D93025` |

---

## 10 · Layout & states

Khung cửa sổ macOS · title bar · toolbar · ba cột.

```
┌─────────────────────────────────────────────────────────┐
│ ● ● ●            gitui · test                            │  title bar (30px)
├─────────────────────────────────────────────────────────┤
│ Toolbar — actions (trái)              utilities (phải)   │  toolbar (38px)
├──────────────┬───────────────────────────┬──────────────┤
│ Rail · 244px │ Center                    │ Diff · 400px │
│ Search +     │ Filter · tabs · changes   │ Preview file │
│ repo list    │ · commit box              │              │
└──────────────┴───────────────────────────┴──────────────┘
```

### Empty states

- **No file selected** — icon tròn 72px trên nền surface container + tiêu đề + mô tả ngắn.
- **Working tree clean** — khi repo không có thay đổi.
- **No staged changes / No stashes** — thẻ viền nét đứt, hướng dẫn hành động kế tiếp.

---

## 11 · Motion

Chuyển động ngắn, có chủ đích — không lặp vô hạn.

| Tương tác | Thời lượng | Easing |
|---|---|---|
| Ripple lan từ điểm chạm | 450–600ms | ease-out |
| Hover / pressed state layer | 120ms | ease |
| Checkbox tick (scale + fade) | 120ms | ease |
| Snackbar trượt lên | 250ms | ease |
| Đổi variant / accent | 250ms | ease |

---

*Material Git Client · Design Specification — Material 3 (Material You) · Light · Accent `#1A73E8`.*
*Tài liệu sinh kèm prototype tương tác “Material Git Client.html”.*
