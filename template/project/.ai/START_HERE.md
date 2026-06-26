\
# State Machine Rule

Before doing anything, read:

- `.ai/STATE.md`
- `.ai/12_STATE_MACHINE/STATE_MACHINE.md`

AI must only perform actions allowed by the current phase.

If current phase is PLAN, AI must produce a repair plan only and must not edit code.


# Branch Safety Rule

Before editing any code, AI must run:

```bash
git branch --show-current
AI must stop if current branch is:

main
feature/aios-v5
any AIOS framework branch

AI may only edit product code on branches starting with:

fix/
bugfix/
hotfix/

If the branch is invalid, AI must ask the human to create a proper bugfix branch.



# AIOS Runtime v6.6 Rule

Before doing any project work, read:

1. `.ai/11_RUNTIME/runtime.json`
2. `.ai/11_RUNTIME/AI_RUNTIME.md`
3. `.ai/token-budget.md`
4. `.ai/module-map.json`
5. `.ai/09_MEMORY/SESSION.md`
6. `.ai/09_MEMORY/DECISIONS.md`
7. `.ai/09_MEMORY/ARCHITECTURE.md`

AI must use context routing before reading source code.

AI must pass review gate before editing.

AI must update memory and report files after work.




# Context Routing Rule



Before searching the repository:



1\. Read `.ai/module-map.json`

2\. Find the selected Bug ID

3\. Read the mapped context file under `.ai/07\_CONTEXT/`

4\. Only read files listed in that context file

5\. Read `.ai/token-budget.md`

6\. Pass `.ai/08\_REVIEW/BUG\_REVIEW.md`



Do not perform global search before reading the context file.



Do not edit code before human approval.



1\. 閱讀 BOOT



2\. 閱讀 PROJECT\_CONTEXT



3\. 閱讀 MEMORY



4\. 閱讀 STATUS



5\. 閱讀 BUGS



6\. 閱讀 ACCEPTANCE



7\. 閱讀 AGENT\_INDEX



8\. 選擇角色



9\. 開始工作

