# Rollback Workflow｜回復流程

## 目的

當 AI 修改造成錯誤、Build 失敗、畫面更壞時，快速回復到安全狀態。

## 使用時機

- Build 失敗且 2 次內無法修復
- UI 明顯變更超出需求
- 不小心修改無關功能
- 新增套件造成衝突
- 測試通過但主要畫面壞掉

## 流程

### Step 1：停止修改

不要繼續擴大修復範圍。

### Step 2：列出變更

```bash
git status
git diff --stat
git diff
```

### Step 3：判斷回復範圍

- 單一檔案回復
- 整個 commit 回復
- 整個 branch 丟棄

### Step 4：回復

優先使用 Git 安全回復，不要手動亂刪。

### Step 5：更新文件

更新：

- `.ai/01_MANAGEMENT/STATUS.md`
- `.ai/07_REPORT/CHANGELOG.md`
- `.ai/01_MANAGEMENT/DECISION_LOG.md`

## 回報格式

```markdown
## Rollback Report

原因：
回復範圍：
回復檔案：
目前狀態：
下一步建議：
```
