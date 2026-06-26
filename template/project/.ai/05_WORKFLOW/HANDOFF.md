# Handoff Workflow｜Agent 交接流程

## 目的

避免 AI 換角色或換工具後忘記上下文。

## 使用時機

- PM 交給 Frontend
- Frontend 交給 Reviewer
- Reviewer 交給 QA
- QA 交給 Documenter
- Gemini 交給 ChatGPT / Claude / Codex

## 交接格式

```markdown
# Handoff Note

## 任務名稱

## 目前狀態
- 未開始 / 進行中 / 已完成 / 卡住

## 已閱讀文件
- 

## 已完成
- 

## 修改過的檔案
- 

## 尚未完成
- 

## 風險與注意事項
- 

## 下一位 Agent 應該做什麼
1. 
2. 
3. 

## 驗收方式
- 
```

## 規則

- 交接內容必須具體。
- 不可以只寫「已完成」。
- 必須寫出下一步。
- 若有錯誤，必須保留錯誤訊息。
