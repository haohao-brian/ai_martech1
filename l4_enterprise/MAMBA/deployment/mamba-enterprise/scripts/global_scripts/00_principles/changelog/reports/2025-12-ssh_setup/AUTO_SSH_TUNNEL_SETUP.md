# MAMBA ETL 自動 SSH Tunnel 設定

## 🚀 功能說明

所有 MAMBA eBay ETL 腳本現在都支援**自動建立 SSH tunnel**！不需要手動執行連線命令。

## 📋 設定完成

### 新增的功能檔案：
- `scripts/global_scripts/02_db_utils/fn_ensure_mamba_tunnel.R`

### 更新的 ETL 腳本：
- ✅ `eby_ETL_orders_0IM___MAMBA.R` 
- ✅ `eby_ETL_order_details_0IM___MAMBA.R`

## 🔧 運作原理

1. **自動檢查**：腳本執行時會檢查 SSH tunnel 是否已存在
2. **自動建立**：如果不存在，會自動使用 `sshpass` 建立連線
3. **保持連線**：執行完畢後不會關閉 tunnel，讓後續腳本可以使用

## 💻 使用方式

### 方法 1：直接執行 ETL 腳本
```bash
# 直接執行，會自動建立 SSH tunnel
Rscript scripts/update_scripts/eby_ETL_orders_0IM___MAMBA.R
```

### 方法 2：在 R 中使用連線函數
```r
# 載入函數
source("scripts/global_scripts/02_db_utils/fn_ensure_mamba_tunnel.R")

# 自動建立 tunnel 並連接
conn <- fn_connect_mamba_sql(auto_tunnel = TRUE)

# 使用連線...
tables <- dbListTables(conn)

# 斷開連線（保持 tunnel）
fn_disconnect_mamba_sql(conn, close_tunnel = FALSE)
```

## 🔐 認證資訊

腳本會從環境變數或 .env 檔案讀取：
- `EBY_SSH_HOST`: 220.128.138.146
- `EBY_SSH_USER`: kylelin  
- `EBY_SSH_PASSWORD`: 618112
- `EBY_SQL_HOST`: 125.227.84.85
- `EBY_SQL_PORT`: 1433
- `EBY_SQL_DATABASE`: MAMBATEK
- `EBY_SQL_USER`: sa
- `EBY_SQL_PASSWORD`: u3sql@2007

## 📝 前置需求

### 安裝 sshpass（macOS）：
```bash
brew tap hudochenkov/sshpass
brew install hudochenkov/sshpass/sshpass
```

### 檢查是否安裝成功：
```bash
which sshpass
# 應該顯示：/opt/homebrew/bin/sshpass
```

## 🔍 檢查 SSH Tunnel 狀態

```bash
# 查看是否有 tunnel 在運行
ps aux | grep -E "ssh.*1433" | grep -v grep

# 查看 1433 port 是否在監聽
netstat -an | grep "127.0.0.1.1433"
```

## 🛑 手動關閉 SSH Tunnel

```bash
# 如果需要手動關閉 tunnel
pkill -f 'ssh.*1433.*125.227.84.85'
```

## ✅ 優點

1. **自動化**：不需要記住複雜的 SSH 命令
2. **智能**：自動檢查現有連線，避免重複建立
3. **效率**：多個 ETL 腳本可以共用同一個 tunnel
4. **安全**：密碼不會顯示在命令歷史中
5. **容錯**：如果 tunnel 斷線，會自動重新建立

## 🎯 使用情境

現在你可以直接執行 ETL 管線，不需要擔心連線問題：

```bash
# 完整 ETL 管線（會自動處理連線）
Rscript scripts/update_scripts/eby_ETL_orders_0IM___MAMBA.R
Rscript scripts/update_scripts/eby_ETL_orders_1ST___MAMBA.R
Rscript scripts/update_scripts/eby_ETL_order_details_0IM___MAMBA.R
Rscript scripts/update_scripts/eby_ETL_order_details_1ST___MAMBA.R
Rscript scripts/update_scripts/eby_ETL_sales_2TR___MAMBA.R
```

每個腳本都會：
1. 檢查 SSH tunnel 是否存在
2. 如果不存在，自動建立
3. 執行 ETL 邏輯
4. 保持 tunnel 開啟給下一個腳本使用

---

*自動連線功能實作日期：2025-08-29*  
*遵循 MAMBA 架構原則：MP096 (Data Storage Selection Strategy)*