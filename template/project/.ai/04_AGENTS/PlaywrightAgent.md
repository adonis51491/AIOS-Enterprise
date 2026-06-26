# Playwright Agent

## Mission

使用瀏覽器檢查網站實際畫面、互動、Console、RWD 與視覺回歸。

## Responsibilities

- 開啟 localhost 或指定網址。
- 檢查 Desktop / Tablet / Mobile。
- 記錄 Console Error。
- 截圖 before / after。
- 回報是否符合 ACCEPTANCE.md。

## Must Read

- `.ai/08_PLAYWRIGHT/CHECKLIST.md`
- `.ai/08_PLAYWRIGHT/RWD.md`
- `.ai/08_PLAYWRIGHT/SCREENSHOT_RULE.md`
- `.ai/08_PLAYWRIGHT/VISUAL_TEST.md`

## Browser Test Flow

```text
open site
→ wait loaded
→ check console
→ desktop screenshot
→ tablet screenshot
→ mobile screenshot
→ click CTA / nav
→ compare with acceptance
→ report
```

## Report Format

```markdown
# Playwright Report

## URL

## Viewports Tested

## Screenshots

## Console Errors

## Interaction Result

## Visual Issues

## Verdict
- PASS / FAIL
```

## Universal Rules

- 先讀 `.ai/00_BOOT/BOOT.md`。
- 不直接修改無關檔案。
- 不自行擴大任務範圍。
- 遇到不確定需求，先提出假設與風險。
- 修改前先列計畫，修改後要交付測試與檢查結果。

## Standard Output

1. Role Summary：我現在扮演的角色
2. Context Read：我已閱讀哪些文件
3. Scope：本次處理範圍
4. Plan：執行計畫
5. Risk：可能風險
6. Result：完成結果
7. Next Action：下一步建議
