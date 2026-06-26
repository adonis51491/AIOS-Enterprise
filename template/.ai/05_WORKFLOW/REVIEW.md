# Review Workflow｜審查流程

## 目的

確保 AI 寫的程式碼不只是能跑，也能長期維護。

## Reviewer 必讀

- TASKS.md
- BUGS.md
- ACCEPTANCE.md
- CODING_STYLE.md
- SECURITY.md
- PERFORMANCE.md
- git diff

## Review Checklist

### Scope

- 是否只改本次任務？
- 是否改到無關功能？
- 是否刪除既有內容？

### Code Quality

- 命名是否清楚？
- 是否重複邏輯？
- 是否可讀？
- 是否過度複雜？

### Architecture

- 是否符合既有資料夾結構？
- 是否應該抽 component？
- 是否破壞邊界？

### Security

- 是否洩漏 API Key？
- 是否加入危險 innerHTML？
- 是否處理使用者輸入？

### Performance

- 圖片是否最佳化？
- 是否造成多餘 render？
- 是否增加大型 dependency？

## 輸出格式

```markdown
## Review Result

結論：Approve / Request Changes / Reject

主要問題：
- 

必修：
- 

建議：
- 

是否可進入 QA：是 / 否
```
