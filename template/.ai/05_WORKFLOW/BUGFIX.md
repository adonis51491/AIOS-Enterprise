# Bugfix Workflow｜Bug 修復流程

## 適用情境

修復已知問題、畫面跑版、互動失效、Console Error、Build Error。

## 流程

### Step 1：確認 Bug

必須先回答：

- Bug 編號
- 影響頁面
- Expected
- Actual
- 重現步驟
- 優先級

### Step 2：重現

若可執行網站：

1. `npm run dev`
2. 打開 `http://localhost:3000`
3. 用 Playwright 或瀏覽器重現
4. 記錄 Console Error

### Step 3：定位原因

請列出：

- 可能檔案
- 可能原因
- 最小修復方案

### Step 4：修復

規則：

- 一次只修一個 Bug
- 不順手重構
- 不改無關樣式
- 不刪資料

### Step 5：驗收

執行：

```bash
npm run build
npm run lint
npm run test
```

若沒有 test script，記錄「專案未設定 test」。

### Step 6：回歸測試

至少檢查：

- 相關頁面
- 首頁
- Navbar
- Footer
- Mobile 375px
- Console 是否有 Error

### Step 7：更新文件

- BUGS.md：標記 fixed
- STATUS.md：更新狀態
- CHANGELOG.md：新增修復紀錄

## Bugfix Report

```markdown
## Bugfix Report

Bug：
原因：
修改檔案：
修復方式：
Build：Pass / Fail
Lint：Pass / Fail / Not configured
Test：Pass / Fail / Not configured
Playwright：Pass / Fail
是否符合 ACCEPTANCE：
```
