# Login Page UI Redesign Report

## Operation Details
- **Date**: 2025-01-20
- **Operation Type**: UI Enhancement
- **Scope**: All Sandbox Apps (BrandEdge, InsightForge, TagPilot, VitalSigns)

## Summary

完成登入頁面的現代簡約風格重新設計，整合 Portal 配色主題，並優化 Logo 顯示效果。

## Changes Made

### 1. 現代簡約風格登入頁面 UI 重新設計

**新增檔案**:
- `scripts/global_scripts/19_CSS/login.css` - 完整的登入頁面樣式系統

**修改檔案**:
- `scripts/global_scripts/11_rshinyapp_utils/supabase_auth/module_login_supabase.R`
  - 新增 `app_icon` 參數支援
  - 套用新的 CSS class（`login-wrapper`, `login-card`, `login-form-group` 等）

**設計特點**:
- CSS Variables (Custom Properties) 用於設計 tokens
- DM Sans 字體（Google Fonts）
- 進場動畫（fade-in + slide-up）
- 響應式設計（支援手機螢幕）

### 2. Portal 配色主題整合

**配色方案** (from https://ai-martech.vercel.app):

| Token | 顏色 | 用途 |
|-------|------|------|
| `--login-text-primary` | `#2C3E50` | 深藍灰主色 |
| `--login-success` | `#18BC9C` | 青綠色（成功狀態）|
| `--login-error` | `#E74C3C` | 紅色（錯誤狀態）|
| `--login-warning` | `#F39C12` | 橘色（警告狀態）|

**背景設計**:
```css
background: linear-gradient(135deg, #f5f7fa 0%, #e4e8eb 100%);
```

### 3. Logo 優化

**變更**:
- 將 Logo 從 JPG（白色背景）更換為透明背景 PNG
- Logo 尺寸從 72px 調整為 100px（約 24% 的卡片寬度 420px）
- 新增 drop-shadow 效果增加立體感

**檔案**:
- `scripts/global_scripts/24_assets/icons/app_icon.png` - 新版透明背景 Logo
- `scripts/global_scripts/24_assets/icons/app_icon_v1.png` - 舊版備份

### 4. 語言選單隱藏

**變更**:
- `loginSupabaseUI()` 參數 `show_language_selector` 預設值從 `TRUE` 改為 `FALSE`
- 登入頁面不再顯示語言選擇下拉選單

## Affected Files

| 檔案 | 變更類型 |
|------|----------|
| `scripts/global_scripts/19_CSS/login.css` | 新增 |
| `scripts/global_scripts/11_rshinyapp_utils/supabase_auth/module_login_supabase.R` | 修改 |
| `scripts/global_scripts/11_rshinyapp_utils/ui_generator.R` | 修改（載入 CSS）|
| `scripts/global_scripts/24_assets/icons/app_icon.png` | 替換 |
| `scripts/global_scripts/24_assets/icons/app_icon_v1.png` | 新增（備份）|

## Deployment

已部署到所有 Sandbox Apps：

| App | GitHub Repo | 狀態 |
|-----|-------------|------|
| BrandEdge | `sandbox_brandedge` | ✅ Deployed |
| InsightForge | `sandbox_insightforge` | ✅ Deployed |
| TagPilot | `sandbox_tagpilot` | ✅ Deployed |
| VitalSigns | `sandbox_vitalsigns` | ✅ Deployed |

## Git Commits

### sandbox_test (ai_martech_sandbox)
- `9833c60` feat: 登入頁面 logo 預設使用 global_scripts 中的 icon
- `5176b52` feat: 現代簡約風格登入頁面 UI 重新設計
- `16100d9` style: 隱藏語言選單 + Portal 配色主題
- `ee1861d` style: 更新 logo 為透明背景 PNG
- `1a8f28c` style: 調大 logo 尺寸 72px → 100px

### global_scripts (ai_martech_global_scripts)
- 透過 `git subrepo push` 同步上述所有變更

## Design Rationale

### Logo 尺寸比例
- 登入卡片寬度：420px
- Logo 高度：100px（約 24% 卡片寬度）
- 此比例在視覺上平衡，既不會太小被忽略，也不會太大喧賓奪主

### CSS drop-shadow vs box-shadow
- 使用 `drop-shadow` 而非 `box-shadow`，因為 Logo 是透明背景圖片
- `drop-shadow` 會依照圖片實際輪廓產生陰影，效果更自然

### Portal 配色選擇
- 深藍灰 `#2C3E50` 作為主色調，專業穩重
- 青綠 `#18BC9C` 作為成功/強調色，活潑但不突兀
- 統一的配色系統確保品牌一致性

## Verification

- [x] 本地測試登入頁面顯示正常
- [x] Logo 透明背景正確顯示
- [x] Portal 配色正確套用
- [x] 語言選單已隱藏
- [x] 所有 4 個 App 已部署
- [x] global_scripts subrepo 已同步

---

**Author**: Claude Code
**Last Updated**: 2025-01-20
