---
template: statement
duration: 21
marker: The Problem
transition: fade
---

Distributing requests is not the same as scheduling work.

---

Load balancers distribute incoming requests across servers, but generally do not know whether a particular worker can begin a specific request immediately. This matters for CPU-heavy workloads: assigning overlapping CPU-bound requests to the same worker creates local queueing and increases tail latency.
