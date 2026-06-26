# Hotfix Workflow｜緊急修復流程

## 適用情境

- 線上網站無法使用
- Build / Deploy 失敗
- 主要 CTA / 表單 / 登入失效
- 嚴重版面破壞

## 原則

Hotfix 只做最小修復，不做優化、不做重構。

## 流程

1. 確認問題是否 P0 / P1
2. 建立 hotfix branch
3. 找出最小修復點
4. 修改
5. 執行 build
6. 檢查主要路徑
7. 發布
8. 補寫文件與回顧

## 不允許

- 新增大型功能
- 更換框架
- 大改 UI
- 新增大套件
- 同時修多個低優先問題

## Hotfix Report

```markdown
## Hotfix Report

緊急問題：
影響範圍：
修復方式：
修改檔案：
部署狀態：
後續需補強：
```
