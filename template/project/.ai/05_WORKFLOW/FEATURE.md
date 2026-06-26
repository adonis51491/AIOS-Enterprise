# Feature Workflow｜新功能開發流程

## 適用情境

新增頁面、元件、互動、API、資料流程或重要內容區塊。

## 參與 Agent

PM → Architect → Developer → Reviewer → QA → Documenter

## 流程

### 1. PM 定義需求

輸出：

```markdown
User Story:
身為 [角色]，我想要 [功能]，以便 [價值]。

Acceptance Criteria:
- 
```

### 2. Architect 判斷設計

必須回答：

- 是否需要新 component？
- 是否影響 API / Database？
- 是否可用既有元件完成？
- 是否有安全或效能風險？

### 3. Developer 實作

規則：

- 最小修改
- 不新增不必要套件
- 不破壞既有頁面
- 不混入其他需求

### 4. Reviewer 審查

檢查：

- 可讀性
- 架構一致性
- 命名
- 效能
- 安全

### 5. QA 驗收

執行：

```bash
npm run build
npm run lint
npm run test
npm run dev
```

再用 Playwright 檢查 Desktop / Tablet / Mobile。

### 6. Documenter 更新

更新：

- STATUS.md
- CHANGELOG.md
- DECISION_LOG.md（若有架構決策）
- README.md（若影響使用方式）

## 完成回報

```markdown
## Feature Report

新增功能：
修改檔案：
測試結果：
驗收結果：
風險：
後續建議：
```
