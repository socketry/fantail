---
template: diagram
duration: 27
section: Mixed workloads
marker: Tail Latency
transition: fade
---

# Poor placement appears in the tail.

<p class="fantail-subtitle">The system can have spare capacity while individual requests wait inside the wrong worker.</p>

<div class="tail-distribution">
	<div class="percentile-band fast-band">
		<div class="percentile-label"><strong>P50</strong><span>capacity matched</span></div>
		<div class="request-dots" aria-label="Most requests complete promptly">
			<span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span>
		</div>
		<p>Assigned to a worker that could begin immediately.</p>
	</div>
	<div class="percentile-band tail-band">
		<div class="percentile-label"><strong>P90+</strong><span>locally queued</span></div>
		<div class="request-dots" aria-label="A minority of requests wait behind long work">
			<span></span><span></span>
		</div>
		<p>Committed to a worker that could not begin it.</p>
	</div>
</div>
<div class="causal-chain">
	<span>Spare capacity elsewhere</span><b>→</b><span>Request already committed</span><b>→</b><span>Local waiting</span><b>→</b><span class="tail-outcome">High P90 / P95 / P99</span>
</div>

---

Over-admission does not necessarily make the median look unhealthy. Most requests may reach workers that can begin them immediately, while a minority are committed to busy workers and wait despite spare capacity elsewhere. That imbalance appears first in P90, P95, and P99 latency. Response utilization arrives after placement and cannot correct those requests.
