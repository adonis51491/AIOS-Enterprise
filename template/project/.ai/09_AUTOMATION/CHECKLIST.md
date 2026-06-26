# Automation Checklist

每次修改完成後，AI 必須依序檢查：

## Local

- [ ] 安裝依賴完成
- [ ] `npm run build` 通過
- [ ] `npm run lint` 通過，若專案有設定
- [ ] `npm run test` 通過，若專案有設定
- [ ] `npm run dev` 可啟動

## Browser

- [ ] 首頁可開啟
- [ ] Console 無 Error
- [ ] Network 無 404 / 500
- [ ] Desktop 檢查通過
- [ ] Tablet 檢查通過
- [ ] Mobile 檢查通過

## Report

- [ ] 更新 `.ai/01_MANAGEMENT/STATUS.md`
- [ ] 更新 `.ai/07_REPORT/CHANGELOG.md`
- [ ] 產生 QA Report
- [ ] 提供 Commit Message
- [ ] 提供 PR Summary
