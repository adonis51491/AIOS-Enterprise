# Agent Index

AIOS Enterprise v6 使用「能力導向」Agent 架構。

## Core Agents

- `Developer.md`：總工程師入口，負責判斷任務與實作
- `Planner.md`：需求拆解、任務排序、驗收標準
- `Researcher.md`：技術查證與方案比較
- `Architect.md`：架構與技術決策
- `Reviewer.md`：Code Review 與風險審查
- `QA.md`：測試與驗收
- `Release.md`：發布、版本紀錄、回滾計畫
- `Documenter.md`：文件同步

## Specialist Agents

- `Frontend.md`：Next.js、React、Tailwind、RWD
- `Backend.md`：API、Prisma、Database、Auth
- `UX.md`：使用者體驗、文案、流程
- `Security.md`：安全與敏感功能
- `DevOps.md`：部署、CI/CD、Vercel、GitHub Actions
- `PlaywrightAgent.md`：瀏覽器測試、截圖、視覺驗收

## 建議入口

一般修 Bug 或功能開發：先讀 `Developer.md`。

需求不清楚：先讀 `Planner.md`。

部署出錯：先讀 `DevOps.md`。

畫面問題：先讀 `Frontend.md` + `UX.md` + `PlaywrightAgent.md`。
