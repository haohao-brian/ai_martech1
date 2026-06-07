#!/usr/bin/env Rscript
# =============================================================
# deploy_now.R - MAMBA Enterprise Manual Deployment
# =============================================================
# 用途：手動部署到 Posit Connect（正常情況用 git push 自動部署）
# 使用方式：cd deployment/mamba-enterprise && Rscript deploy_now.R

cat("📂 部署目錄:", getwd(), "\n")

# 確認在部署目錄
if (!file.exists("app.R") || !file.exists("app_config.yaml")) {
  stop("請從 deployment/mamba-enterprise/ 目錄執行此腳本")
}

# 確認有 scripts
if (!dir.exists("scripts/global_scripts")) {
  stop("scripts/global_scripts/ 不存在，請先執行 make deploy-sync")
}

# 載入部署配置
if (file.exists("scripts/global_scripts/23_deployment/sc_deployment_config.R")) {
  source("scripts/global_scripts/23_deployment/sc_deployment_config.R")
} else {
  cat("⚠️  找不到部署腳本，使用 rsconnect 直接部署\n")

  if (!requireNamespace("rsconnect", quietly = TRUE)) {
    stop("請安裝 rsconnect 套件: install.packages('rsconnect')")
  }

  config <- yaml::read_yaml("app_config.yaml")

  cat("🚀 部署", config$app$name, "...\n")
  rsconnect::deployApp(
    appDir = ".",
    appPrimaryDoc = "app.R",
    appName = config$deployment$app_name %||% "mamba-enterprise",
    account = config$deployment$account_name,
    server = "connect.posit.cloud",
    forceUpdate = TRUE
  )
}
