# AIOS v5 Starter Kit

這是一套可放進 GitHub 專案的 AI 開發作業系統，適合 Gemini Computer Use、ChatGPT、Claude Code、Codex、Cursor 等工具共同使用。

## 快速使用

1. 將本資料夾內容複製到你的專案根目錄。
2. 先更新 `.ai/00\_BOOT/PROJECT\_CONTEXT.md`。
3. 再更新 `.ai/01\_MANAGEMENT/STATUS.md`、`TASKS.md`、`BUGS.md`、`ACCEPTANCE.md`。
4. 每次請 AI 工作時，先貼 `prompts/START\_WORK.md`。

## 核心原則

* AI 不可直接亂改程式。
* 每次先讀規則、狀態、任務、Bug、驗收標準。
* 一次只處理一個主要任務。
* 修改後必須 Build、Lint、Test、Playwright 檢查。
* 完成後更新 STATUS、CHANGELOG、DECISION\_LOG。



## Phase 2 Agent Mode

Phase 2 已補齊多 Agent 手冊。建議從 `prompts/PHASE2\_AGENT\_MODE.md` 開始，讓 Gemini Computer Use 先做任務分派，再開始修改。



## Phase 3｜Workflow Mode

Phase 3 補齊完整工作流程，讓 AI 不只是「有角色」，而是能依照固定流程完成任務。

新增重點：

* Workflow Index
* Triage 任務分類
* Feature 開發流程
* Bugfix 修復流程
* Hotfix 緊急修復流程
* Review 審查流程
* Release 發布流程
* Handoff 交接流程
* Rollback 回復流程
* Retrospective 回顧流程
* Gemini Computer Use 專用 Phase 3 Prompt

建議使用方式：

1. 先把本套件複製進專案根目錄。
2. 打開 Gemini Computer Use。
3. 貼上 `prompts/PHASE3\_WORKFLOW\_MODE.md`。
4. 等 AI 輸出 Workflow Plan。
5. 確認後，再讓 AI 執行 Bugfix / Feature / Release。



## Phase 4 Automation Layer

已加入 GitHub Actions、Playwright、QA Report、Screenshot、Lighthouse、Deploy、Rollback 與 MCP Ready 文件。

建議安裝：

```bash
npm install -D @playwright/test
npx playwright install chromium
```

建議在 `package.json` 加入：

```json
{
  "scripts": {
    "test:e2e": "playwright test"
  }
}
```

