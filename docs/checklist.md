# Checklist Generator

## Sources

- `STATUS.md`: priority
- `BUGS.md`: specification
- `ACCEPTANCE.md`: acceptance

## Required headings

```markdown
## BUG-001：問題名稱
```

```markdown
## 八、1-7 預約衝突（BUG-001）
```

The Bug ID must appear on the same acceptance heading line.

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
-File scripts\aios.ps1 `
checklist
```

## Output

`.aios/reports/TODAY_CHECKLIST.md`
