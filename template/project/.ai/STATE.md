\# AIOS State



\## Current Phase



PLAN



\## Allowed Actions



\- Read AIOS runtime files

\- Read STATUS.md

\- Read BUGS.md

\- Read ACCEPTANCE.md

\- Read module-map.json

\- Read mapped context file

\- Read only mapped source files

\- Produce repair plan



\## Forbidden Actions



\- Edit code

\- Run destructive commands

\- Commit

\- Push

\- Change unrelated files

\- Search globally before approval



\## Phase Rules



\### PLAN



AI may analyze and propose a plan only.



\### EDIT



AI may modify only approved files.



\### VERIFY



AI may run validation commands.



\### REPORT



AI may update memory and report files.



\### COMMIT



AI may prepare commit message only.

Human must execute commit and push unless explicitly approved.

