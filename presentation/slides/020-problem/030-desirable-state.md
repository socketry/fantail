---
template: statement
duration: 25
marker: Desirable State
transition: fade
---

Keep each request globally assignable until a compatible worker is ready to begin it.

---

This is the premise Fantail is built around: admission before assignment. Pending requests wait once, in a global queue. Workers advertise permits as a leading capacity signal, and the oldest compatible request is assigned only when a permit can be reserved. Work therefore does not disappear into a worker-local queue or connection pool before it can run.
