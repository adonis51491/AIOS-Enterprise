# Phase 4 Automation Layer

這一層讓 AIOS 從「文件工作流」升級成「可執行工作流」。

核心目標：

1. 讓 AI 每次修改後都能執行 build / lint / test。
2. 使用 Playwright 檢查桌機、平板、手機畫面。
3. 產生截圖與 QA Report。
4. 透過 GitHub Actions 在 PR / Push 時自動驗證。
5. 預留 MCP、部署、Lighthouse 與報告整合。

AI 必須先讀：

- `.ai/00_BOOT/BOOT.md`
- `.ai/05_WORKFLOW/*.md`
- `.ai/09_AUTOMATION/CHECKLIST.md`
