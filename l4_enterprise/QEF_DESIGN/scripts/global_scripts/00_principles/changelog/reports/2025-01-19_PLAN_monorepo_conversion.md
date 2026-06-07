---
archived_from: manual_migration
archived_at: 2026-01-26T00:00:00+08:00
status: planned
original_location: changelog/plans/2025-01-19_wonderful_food_monorepo_conversion.md
---

# Wonderful Food Monorepo 轉換計劃

## 目標
將 wonderful_food 的 3 個獨立 Git repos 轉換為「開發集中、部署分散」的 monorepo 架構。

---

## 模組分析結果（Claude 分析）

### modules/ 分類

| 分類 | 檔案 | 來源 | 說明 |
|------|------|------|------|
| **shared/** | `module_dna.R` | BrandEdge + TagPilot | MD5 完全相同 ✅ |
| **shared/** | `module_wo_b.R` | InsightForge + TagPilot | MD5 完全相同 ✅ |
| **brandedge/** | `module_brandedge_flagship.R` | BrandEdge | 旗艦版核心 |
| **brandedge/** | `module_brandedge_flagship_with_prompt_manager.R` | BrandEdge | 含 Prompt 管理 |
| **brandedge/** | `module_market_profile_enhanced.R` | BrandEdge | 市場檔案增強 |
| **insightforge/** | `module_keyword_ads.R` | InsightForge | 關鍵字廣告 |
| **insightforge/** | `module_product_dev.R` | InsightForge | 產品開發 |
| **insightforge/** | `module_score_v2.R` | InsightForge | 評分 v2 |
| **insightforge/** | `module_wo_b_v2.R` | InsightForge | OpenAI v2 |
| **tagpilot/** | `module_dna_multi_VS.R` | TagPilot | DNA 多變數 VS |
| **tagpilot/** | `module_dna_multi_premium.R` | TagPilot | DNA 多變數 Premium |
| **tagpilot/** | `module_dna_multi_premium2.R` | TagPilot | DNA 多變數 Premium v2 |
| **tagpilot/** | `module_dna_multi_pro2.R` | TagPilot | DNA 多變數 Pro v2 |

**需人工決策**（三個 app 都有但內容不同）：
- `module_login.R` → 建議：提取通用邏輯，參數化品牌名稱
- `module_upload.R` → 建議：評估差異後決定
- `module_dna_multi.R` → 建議：差異 15%，可能只是參數差異
- `module_upload_complete_score.R` → 建議：差異大(724 vs 492行)，保持專用
- `module_score.R` → 建議：差異大(246 vs 147行)，保持專用

### utils/ 分類

| 分類 | 檔案 | 建議來源 | 說明 |
|------|------|----------|------|
| **shared/** | `data_access.R` | 統一版本 | 核心相同，差異在連接配置 |
| **shared/** | `hint_system.R` | InsightForge 版本 | InsightForge 版本更完整 (221行 vs 112行) |
| **shared/** | `prompt_manager.R` | InsightForge 版本 | InsightForge 版本更完整 (267行 vs 183行) |
| **shared/** | `openai_utils.R` | InsightForge | 其他 app 也可能需要 |

---

## 最終結構

```
wonderful_food/
├── CLAUDE.md                       # Claude 操作指引
├── README.md                       # 專案說明
├── Makefile                        # 同步腳本
│
├── wonderful_food_dev/             # 開發環境
│   ├── app_brandedge.R
│   ├── app_insightforge.R
│   ├── app_tagpilot.R
│   ├── modules/
│   │   ├── shared/                 # 共用模組
│   │   ├── brandedge/              # BrandEdge 專用
│   │   ├── insightforge/           # InsightForge 專用
│   │   └── tagpilot/               # TagPilot 專用
│   ├── utils/
│   │   ├── shared/
│   │   ├── brandedge/
│   │   ├── insightforge/
│   │   └── tagpilot/
│   ├── config/{brandedge,insightforge,tagpilot}/
│   ├── database/
│   ├── www/
│   └── scripts/global_scripts/     # 單一份 subrepo
│
└── deployment/                     # 部署環境（保留現有 repos）
    ├── brandedge/                  # wonderful_food_BrandEdge_premium
    ├── insightforge/               # wonderful_food_InsightForge_premium
    └── tagpilot/                   # wonderful_food_TagPilot_premium
```

## 實施步驟

### Phase 1: 準備工作
1. [ ] 備份現有 repos 到 archive/
2. [ ] 建立 wonderful_food_dev/ 目錄結構
3. [ ] Clone 現有 repos 到 deployment/

### Phase 2: 模組分類
4. [ ] 分析 modules 哪些共用、哪些專用
5. [ ] 分析 utils 哪些共用、哪些專用
6. [ ] 複製並分類檔案到 wonderful_food_dev/

### Phase 3: 程式碼修改
7. [ ] 修改 app_brandedge.R 的 source 路徑（shared/ + brandedge/）
8. [ ] 修改 app_insightforge.R 的 source 路徑
9. [ ] 修改 app_tagpilot.R 的 source 路徑

### Phase 4: 同步機制
10. [ ] 建立 Makefile（參考 sandbox/Makefile）
11. [ ] 測試 `make brandedge` 同步
12. [ ] 測試 `make insightforge` 同步
13. [ ] 測試 `make tagpilot` 同步

### Phase 5: 驗證
14. [ ] 推送到 deployment repos
15. [ ] 確認 Posit Connect 自動部署正常
16. [ ] 撰寫 CLAUDE.md 和 README.md

## 關鍵決策

| 決策 | 選擇 | 原因 |
|------|------|------|
| 模組組織 | 分層目錄 (shared/+專用/) | 定制版本，不能全部覆蓋 |
| 現有 repos | 保留作為 deployment | 不影響 Posit Connect 設定 |
| 同步方式 | Makefile + rsync | 與 sandbox 一致 |
| global_scripts | 各 deployment 獨立 subrepo | 避免版本衝突 |

## 關鍵檔案

**參考**:
- `/l3_premium/sandbox/Makefile` - 同步腳本範本
- `/l3_premium/sandbox/CLAUDE.md` - 文檔風格

**需修改**:
- `wonderful_food_BrandEdge_premium/app.R` → `app_brandedge.R`
- `wonderful_food_InsightForge_premium/app.R` → `app_insightforge.R`
- `wonderful_food_TagPilot_premium/app.R` → `app_tagpilot.R`

## 驗證方式

1. **本地測試**: 在 wonderful_food_dev/ 執行 `Rscript app_brandedge.R`
2. **同步測試**: `make brandedge` 後檢查 deployment/brandedge/ 結構
3. **部署測試**: git push 後確認 Posit Connect 自動部署成功

## 注意事項

- 所有開發在 wonderful_food_dev/ 進行
- deployment/ 只做同步和推送，不直接編輯
- global_scripts 需要在各 deployment 分別 subrepo pull
