---
template: diagram
duration: 26
section: Fantail provides
marker: Summary
transition: fade
---

# An application-aware scheduling layer for HTTP.

<div class="summary-grid">
	<div><strong>Global admission</strong><span>Keep work assignable until capacity exists.</span></div>
	<div><strong>Explicit permits</strong><span>Route using a leading indicator of worker capacity.</span></div>
	<div><strong>Queue policy</strong><span>Classify, balance, bound, and shed requests.</span></div>
	<div><strong>HTTP semantics</strong><span>Return clear overload responses instead of hidden backlog.</span></div>
</div>

---

Fantail turns worker readiness into an explicit scheduling primitive. The design preserves baseline capacity and lets applications define how excess load is queued or rejected. In summary, it gives us the control required to handle mixed workloads efficiently, while providing leading scale up and scale down signals, avoiding overload and enabling cost effective deployment.
