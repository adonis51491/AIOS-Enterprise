# Release Workflow｜發布流程

## 目的

發布前做完整檢查，避免把壞掉的版本推上線。

## Release 前檢查

### Code

```bash
npm run build
npm run lint
npm run test
```

### UI

- Desktop Chrome
- Desktop Edge
- Mobile 375px
- Tablet 768px
- Console Error
- Network Error

### Content

- 首頁文字
- CTA
- Footer
- SEO title / description

### Docs

確認更新：

- STATUS.md
- CHANGELOG.md
- RELEASE_NOTE.md
- DECISION_LOG.md

## Release Note 格式

```markdown
# Release Note

版本：
日期：

## 新增
- 

## 修復
- 

## 改善
- 

## 已知問題
- 

## 驗收
Build：
Lint：
Test：
Playwright：
```
