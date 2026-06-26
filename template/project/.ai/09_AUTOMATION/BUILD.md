# Build Automation

AI 修改程式後必須執行：

```bash
npm run build
```

如果失敗：

1. 停止下一步。
2. 讀取錯誤訊息。
3. 只修復 build error。
4. 再次執行 build。
5. 不得跳過 build 失敗。

回報格式：

```md
## Build Result
Status: PASS / FAIL
Command: npm run build
Notes:
```
