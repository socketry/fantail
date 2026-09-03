---
template: statement
duration: 25
marker: Desirable State
transition: fade
---

Keep pending requests globally assignable until a worker advertises a permit.

---

This is the scheduling property we want. A permit is the worker's leading capacity signal: it says the worker can begin another request now. The next eligible worker with a permit receives the oldest compatible request, and no request is hidden inside an unavailable worker's local queue or connection pool.
