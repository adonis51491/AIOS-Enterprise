# Triage Workflow｜任務分類流程

## 目的

在 AI 開始修改前，先判斷任務類型、影響範圍、風險與優先順序。

## 適用情境

- 新增需求不清楚
- BUGS.md 有多個問題
- 使用者只說「幫我修網站」
- Gemini Computer Use 看到畫面異常，但還不知道原因

## 參與 Agent

1. PM：整理需求
2. Architect：判斷技術影響
3. QA：判斷驗收方式
4. Reviewer：判斷風險

## 流程

### Step 1：讀取資料

必讀：

- `.ai/00_BOOT/PROJECT_CONTEXT.md`
- `.ai/01_MANAGEMENT/STATUS.md`
- `.ai/01_MANAGEMENT/TASKS.md`
- `.ai/01_MANAGEMENT/BUGS.md`
- `.ai/01_MANAGEMENT/ACCEPTANCE.md`
- `.ai/00_BOOT/MEMORY.md`

### Step 2：分類任務

請判斷任務屬於：

- Feature
- Bugfix
- Hotfix
- Refactor
- UI polish
- Documentation
- Test only
- Research only

### Step 3：優先級

使用以下等級：

- P0：網站不能用、Build 失敗、主要流程中斷
- P1：重要功能異常、手機版嚴重跑版
- P2：一般錯誤、局部體驗問題
- P3：小型視覺或文字調整

### Step 4：輸出格式

```markdown
## Triage Result

任務類型：
優先級：
影響頁面：
可能影響檔案：
風險：
建議負責 Agent：
建議 Workflow：
是否需要人類確認：是 / 否
```

## 停止條件

若涉及以下內容，請停止並等待確認：

- API 行為變更
- Database Schema 變更
- Auth / Payment / Security
- 大型套件新增
- 架構重構
- 刪除既有內容
