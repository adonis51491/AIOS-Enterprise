# Start Workflow｜每次開工流程

## 目的

讓 AI 在開始前先恢復上下文，避免直接亂改。

## 必讀順序

1. `.ai/00_BOOT/BOOT.md`
2. `.ai/00_BOOT/PROJECT_CONTEXT.md`
3. `.ai/00_BOOT/MEMORY.md`
4. `.ai/01_MANAGEMENT/STATUS.md`
5. `.ai/01_MANAGEMENT/TASKS.md`
6. `.ai/01_MANAGEMENT/BUGS.md`
7. `.ai/01_MANAGEMENT/ACCEPTANCE.md`
8. `.ai/03_RULES/CODING_STYLE.md`
9. `.ai/03_RULES/TEST.md`
10. `.ai/05_WORKFLOW/WORKFLOW_INDEX.md`

## 開工前輸出

```markdown
## Start Summary

我理解的專案：

目前狀態：

本次任務：

相關 Bug / Task：

我不會修改的範圍：

計畫：
1. 
2. 
3. 

需要確認：
- 
```

## 規則

- 沒有計畫，不准修改。
- 沒有確認影響範圍，不准修改。
- 如果任務不清楚，先做 TRIAGE。
