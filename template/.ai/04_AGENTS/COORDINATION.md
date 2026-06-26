# Agent Coordination v6

## Default Flow

Planner → Developer → Reviewer → QA → Documenter → Release

## Bugfix Flow

1. Planner：確認 Bug、重現方式、優先級
2. Developer：提出修復計畫並修改
3. Reviewer：檢查程式品質與風險
4. QA：Build、測試、Playwright 驗收
5. Documenter：更新 STATUS / CHANGELOG
6. Release：確認部署與回滾方案

## UI Flow

Planner → Frontend → UX → PlaywrightAgent → QA → Reviewer

## Backend Flow

Planner → Backend → Security → Reviewer → QA → DevOps

## Rule

沒有通過 Reviewer 與 QA，不得 Release。
