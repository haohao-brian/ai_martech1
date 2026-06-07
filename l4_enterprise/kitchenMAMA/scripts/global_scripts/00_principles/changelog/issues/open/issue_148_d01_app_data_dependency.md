# Issue #148: D01 Dependency Missing App Data DuckDB Initialization

**Status**: open
**Date**: 2026-02-28
**App**: shared
**Component**: D01_derivations
**Severity**: medium

---

## Summary

`D01` pipeline 執行（`amz_D01_04`）在某些流程中會讀取 `app_data.duckdb` 的 `app_data` 表，但 targets 排程沒有保證 `D00` 先完成，造成 `staged_data.duckdb` 或其表不存在時執行失敗。

## Root Cause

- `_targets_config.yaml` 中 `amz_D01_04` 缺少對 `D00` 的明確依賴宣告。
- 在非線性排程情境下，`amz_D01_04` 可能在 `D00` 尚未建立/填充 `app_data` 時先被執行。

## Evidence

- 失敗現象：`app_data.duckdb`/`app_data` 匯入階段報錯，導致 D01 無法完整跑完。
- 與既有背景一致：舊有 `Issue #144` 已紀錄 `app_data.duckdb` 在部署端的包版問題（`Issue #144` 不同於本次 `targets` 執行順序問題）。

## Resolution (已套用)

1. 在 `_targets_config.yaml` 的 `amz_D01_04` 目標上增加 `depends_on: "D00"`。
2. 以明確依賴順序保證 `D00` 執行完畢後才進入 `amz_D01_04`，避免 app_data 未建立的 race condition。

## Verification

- 依賴調整後，`amz_D01_04` / `amz_D01_06` 皆可正常執行，`app_data` 匯入流程可通過。

## Related

- Issue #144: app_data.duckdb Not Included in Posit Connect Deployment
