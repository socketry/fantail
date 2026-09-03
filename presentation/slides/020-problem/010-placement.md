---
template: statement
duration: 25
marker: The Problem
transition: fade
---

Distributing requests is not the same as scheduling work.

---

Load balancers distribute incoming requests to a set of servers. However, without understanding the types of requests, they are usually unable to efficiently distribute work without internal queueing. This is especially relevant to CPU-heavy requests which cannot be interleaved without increasing worst case latency.
