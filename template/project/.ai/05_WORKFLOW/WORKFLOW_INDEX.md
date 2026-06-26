# AIOS v5 Phase 3｜Workflow Index

本資料夾定義 AI 團隊的標準工作流程。任何 AI Agent 在開始工作前，必須先閱讀：

1. `.ai/00_BOOT/BOOT.md`
2. `.ai/04_AGENTS/COORDINATION.md`
3. 本檔案
4. 對應任務流程文件

## 工作流程總覽

| 流程 | 使用時機 | 主要產出 |
|---|---|---|
| START.md | 每次開始工作 | 任務理解、風險、下一步 |
| FEATURE.md | 新功能開發 | User Story、實作、驗收 |
| BUGFIX.md | 一般 Bug 修復 | 重現、修復、回歸測試 |
| HOTFIX.md | 緊急線上問題 | 最小修復、快速驗證、補文件 |
| REVIEW.md | 程式碼審查 | Approve / Request Changes |
| RELEASE.md | 發布前檢查 | Release Checklist、Release Note |
| RETROSPECTIVE.md | 階段回顧 | 改進項目、Decision Log |
| HANDOFF.md | Agent 交接 | 上下文、已完成、待處理 |
| TRIAGE.md | 任務分類 | 優先級、負責 Agent、範圍 |
| ROLLBACK.md | 修改失敗回復 | 回復計畫、風險控管 |

## 不可跳過的原則

- 先理解，再修改。
- 先提出計畫，再執行。
- 每次只處理一個主要問題。
- 修改後必須驗收。
- 修改後必須更新文件。
- 不確定就停下來問人，不要猜。
