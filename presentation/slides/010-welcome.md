---
template: title
duration: 20
marker: Welcome
transition: fade
---

# Fantail

Worker-aware HTTP load balancing

---

Fantail is an HTTP load balancer built around a simple idea: route work to a worker when that worker is ready to process it. It builds on Falcon's existing long-task admission model, extends it to HTTP/2, and supports multiple queueing strategies for different workloads.
