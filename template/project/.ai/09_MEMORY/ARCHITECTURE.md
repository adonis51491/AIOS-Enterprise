\# Architecture Memory



This file summarizes module-level architecture for AI agents.



\## Appointment Flow



1\. User checks available slots.

2\. Frontend displays available time slots.

3\. User submits appointment request.

4\. Backend validates:

&#x20;  - user identity

&#x20;  - appointment time

&#x20;  - slot availability

&#x20;  - duplicate booking

5\. Backend creates appointment.

6\. Admin or system may approve / reject / cancel.



\## Rule



AI must read the relevant context file before inspecting code.



For appointment-related work:



\- `.ai/07\_CONTEXT/appointment.md`

