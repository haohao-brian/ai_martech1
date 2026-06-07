# App 名稱格式統一

**日期**: 2026-01-20
**類型**: UI/配置變更
**影響範圍**: 所有 Sandbox Apps (BrandEdge, InsightForge, TagPilot, VitalSigns)

---

## 變更摘要

統一所有 App 的名稱顯示格式為雙行顯示：
- **第一行**: 英文名稱
- **第二行**: 中文名稱

中文名稱來源：官方行銷簡報 `20260120_跨境電商AI精準行銷實戰...final.pptx`

---

## 變更內容

### 1. YAML 配置結構更新

所有 App 的 YAML 配置新增/更新 `name_en` 和 `name_zh` 欄位：

| App | 檔案 | name_en | name_zh |
|-----|------|---------|---------|
| TagPilot | `tagpilot_config/tagpilot.yaml` | TagPilot Premium | 顧客標籤行銷引擎 |
| BrandEdge | `brandedge_config/brandedge.yaml` | BrandEdge | 品牌定位策略引擎 |
| InsightForge | `insightforge_config/insightforge.yaml` | InsightForge | 精準行銷引擎 |
| VitalSigns | `vitalsigns_config/vitalsigns.yaml` | VitalSigns | 行銷成長監測引擎 |

**YAML 結構範例**:
```yaml
app_info:
  app_id: "tagpilot"
  name_en: "TagPilot Premium"
  name_zh: "顧客標籤行銷引擎"
  name: "TagPilot Premium"  # 向後兼容，用於瀏覽器標籤等單行場合
```

### 2. ui_generator.R 更新

**檔案**: `utils/ui_generator.R`

`generate_header()` 函數已支援雙行標題顯示：

```r
# 雙行格式支援
app_title <- if (!is.null(config$app_info$name_en) && !is.null(config$app_info$name_zh)) {
HTML(paste0(
    "<div class='app-title-wrapper'>",
    "<span class='app-title-en'>", config$app_info$name_en, "</span>",
    "<span class='app-title-zh'>", config$app_info$name_zh, "</span>",
    "</div>"
))
} else {
config$app_info$name %||% "App"
}
```

### 3. module_login_supabase.R 更新

**檔案**: `scripts/global_scripts/11_rshinyapp_utils/supabase_auth/module_login_supabase.R`

`loginSupabaseUI()` 函數已支援雙行標題：

```r
loginSupabaseUI <- function(id, title = "登入", title_zh = NULL, ...) {
# 支援雙行標題格式
title_element <- if (!is.null(title_zh)) {
    div(class = "login-title-wrapper",
        div(class = "login-title-en", title),
        div(class = "login-title-zh", title_zh))
} else {
    div(class = "login-title", title)
}
}
```

### 4. CSS 樣式新增

**檔案**: `scripts/global_scripts/19_CSS/login.css`

新增以下 CSS 類別：

```css
/* 登入頁面 - 雙行標題 */
.login-title-wrapper {
text-align: center;
margin-bottom: var(--login-spacing-sm);
animation: titleEnter 0.5s var(--login-transition-base) 0.15s both;
}

.login-title-en {
display: block;
font-family: var(--login-font-display);
font-size: 1.75rem;
font-weight: 600;
color: var(--login-text-primary);
letter-spacing: -0.025em;
line-height: 1.2;
}

.login-title-zh {
display: block;
font-family: var(--login-font-body);
font-size: 1rem;
font-weight: 400;
color: var(--login-text-secondary);
margin-top: 0.35rem;
letter-spacing: 0.02em;
}

/* Navbar - 雙行標題 */
.app-title-wrapper {
display: flex;
flex-direction: column;
line-height: 1.15;
padding: 0.25rem 0;
}

.app-title-en {
font-size: 1rem;
font-weight: 600;
color: inherit;
letter-spacing: -0.01em;
}

.app-title-zh {
font-size: 0.75rem;
font-weight: 400;
color: #6c757d;
margin-top: 0.1rem;
}
```

---

## 向後兼容性

- `name` 欄位保留用於瀏覽器標籤等只需單行的場合
- 若 `name_en` 或 `name_zh` 不存在，系統自動 fallback 到 `name` 欄位
- 使用 `%||%` NULL coalescing 運算子確保安全 fallback

---

## 相關原則

- **UI_R001**: UI-Server-Defaults Triple Pattern
- **SO_P016**: Configuration Scope Hierarchy

---

## 變更者

Claude Code (Opus 4.5)
