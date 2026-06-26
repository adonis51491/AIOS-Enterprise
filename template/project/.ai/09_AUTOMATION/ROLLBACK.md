# Rollback Automation

若發現重大錯誤：

1. 停止部署。
2. 記錄錯誤。
3. 找出最近穩定版本。
4. 建議 rollback。
5. 更新 RISK / STATUS / CHANGELOG。

Rollback Commit 格式：

```txt
revert: rollback <feature/bugfix name>
```
