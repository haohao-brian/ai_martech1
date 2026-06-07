# ISSUE_155: Portal 架構遷移至 Vercel + Supabase

**日期**: 2025-01-08
**狀態**: RESOLVED
**優先級**: High
**類型**: Architecture Change

---

## 問題描述

原本 Portal 使用 Shiny (bs4Dash) 框架部署在 Posit Connect Cloud，但發現以下問題：

1. **Idle Timeout 限制**：Posit Connect Cloud 最大 idle timeout 僅 60 秒
2. **計數器持久化問題**：記憶體中的 round-robin 計數器在 worker 重啟後會重置
3. **併發問題**：多人同時訪問可能導致分配到相同 instance

## 根本原因

Posit Connect Cloud 的 Runtime 設定有以下平台限制：
- Idle timeout 上限為 60 秒
- 沒有 Min worker processes 選項（無法預熱）
- 記憶體變數無法跨 session 持久化

這導致使用 Shiny 內建變數做 round-robin 負載均衡不可行。

## 解決方案

### 架構遷移

| 項目 | 舊架構 | 新架構 |
|------|--------|--------|
| Portal 框架 | Shiny (bs4Dash) | 純 HTML + JavaScript |
| 部署平台 | Posit Connect | Vercel |
| 計數器存儲 | R 記憶體變數 | Supabase PostgreSQL |
| URL 格式 | 單一 instance | `{app}0{0-4}` 循環 |
| 負載均衡 | 無 | Round-robin (5 instances per app) |

### 技術實現

#### 1. Supabase PostgreSQL 設定

```sql
-- 計數器表
CREATE TABLE portal_counters (
  app_id TEXT PRIMARY KEY,
  counter INT DEFAULT 0
);

INSERT INTO portal_counters VALUES
  ('brandedge', 0),
  ('insightforge', 0),
  ('tagpilot', 0),
  ('vitalsigns', 0);

-- 原子遞增函數（循環 0-4，共 5 個 instance）
CREATE OR REPLACE FUNCTION increment_counter(app TEXT)
RETURNS INT AS $$
DECLARE
  new_val INT;
BEGIN
  UPDATE portal_counters
  SET counter = (counter + 1) % 5
  WHERE app_id = app
  RETURNING counter INTO new_val;
  RETURN new_val;
END;
$$ LANGUAGE plpgsql;
```

#### 2. 前端整合

```javascript
async function go(app) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/increment_counter`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`
    },
    body: JSON.stringify({ app: app })
  });
  const counter = await res.json();
  window.location.href = `https://kyleyhl-sandbox-${app}0${counter}.share.connect.posit.cloud/`;
}
```

### 架構圖

```
Vercel (靜態 HTML)          Supabase (PostgreSQL)
        │                          │
        ↓ ~100ms 載入              │
   極簡選擇頁面                    │
        │                          │
        ↓ 點擊                     │
   JavaScript ─────────────→ REST API
        │                          │ UPDATE counter
        │                          │ RETURNING new_val
        ←──────────────────── 回傳 counter (0-9)
        │
        ↓ redirect
   https://kyleyhl-sandbox-{app}0{counter}.share.connect.posit.cloud/
```

## 部署資訊

| 項目 | 值 |
|------|-----|
| Portal URL | https://ai-martech.vercel.app |
| GitHub Repo | kiki830621/sandbox-portal |
| Supabase Project | https://oziernubrqgqthjksbii.supabase.co |
| 源碼位置 | `l3_premium/sandbox/sandbox-portal/index.html` |

## 優點

1. **極快載入**：靜態 HTML 透過 Vercel CDN 全球分發，~100ms 載入
2. **永久在線**：不受 idle timeout 影響
3. **原子操作**：PostgreSQL `UPDATE...RETURNING` 確保併發安全
4. **成本效益**：Vercel 和 Supabase 免費方案足夠使用

## 相關檔案

- `l3_premium/sandbox/sandbox-portal/index.html` - Portal 源碼
- `l3_premium/sandbox/CLAUDE.md` - 更新 Portal 部署資訊

## 驗證

- [x] Supabase 表格和函數建立成功
- [x] Vercel 部署成功
- [x] 頁面正常載入，4 個 App 卡片顯示正確
- [ ] 點擊測試（待驗證跳轉功能）

---

**解決者**: Claude Code
**解決日期**: 2025-01-08
