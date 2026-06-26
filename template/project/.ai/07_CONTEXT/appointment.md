\# Appointment Context



\## Module



Appointment / 預約系統



\## Related Bugs



\- BUG-001: 同一預約時段可能被重複預約

\- BUG-002: 可預約過去時間或非法時段



\## Related Files



Read these files first:



\- prisma/schema.prisma

\- src/app/api/appointment/create/route.ts

\- src/app/api/appointment/check/route.ts

\- src/app/api/available-slots/route.ts

\- src/lib/appointment.ts



\## Rules



Do not search the whole repository.



Do not use broad keyword search first.



Pending and approved appointments should be treated as occupying a slot unless project rules state otherwise.



\## Key Acceptance Criteria



\- Concurrent requests allow only one success

\- Second request returns 409 or clear error

\- Backend must enforce conflict prevention

\- Do not rely only on frontend button locking

\- Available slots must not show occupied slots

