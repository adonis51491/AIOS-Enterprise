\# AIOS Checklist Generator



\## Purpose



Generate today's repair checklist from:



1\. `STATUS.md`

2\. `BUGS.md`

3\. `ACCEPTANCE.md`



\## Source Contract



\- `STATUS.md` is the only priority source.

\- `BUGS.md` is the only Bug specification source.

\- `ACCEPTANCE.md` is the only acceptance source.



\## Required Format



Bug heading:



```markdown

\## BUG-001：Bug title

Acceptance heading:



\## 八、1-7 預約衝突（BUG-001）



The Bug ID must appear on the same heading line.



Command

powershell -NoProfile -ExecutionPolicy Bypass `

\-File scripts\\aios.ps1 `

checklist

Output

.aios/reports/TODAY\_CHECKLIST.md

Status Values

NOT\_TESTED

PASS

FAIL

BLOCKED

HUMAN\_CHECK\_REQUIRED

MISSING



\---



