---
template: diagram
duration: 35
marker: Tail Latency
transition: fade
---

<div class="fantail-slide">
	<div class="fantail-heading">
		<p class="fantail-kicker">Mixed workloads</p>
		<h1>Over-admission hides in the tail.</h1>
		<p>Most requests may start promptly; the unlucky minority wait behind incompatible work.</p>
	</div>
	<div class="tail-distribution">
		<div class="percentile-band fast-band">
			<div class="percentile-label"><strong>P50</strong><span>usually healthy</span></div>
			<div class="request-dots" aria-label="Most requests complete promptly">
				<span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span>
			</div>
			<p>Worker was ready, or the work could overlap.</p>
		</div>
		<div class="percentile-band tail-band">
			<div class="percentile-label"><strong>P90+</strong><span>latency expands</span></div>
			<div class="request-dots" aria-label="A minority of requests wait behind long work">
				<span></span><span></span>
			</div>
			<p>Request was accepted by a worker already occupied by a long task.</p>
		</div>
	</div>
	<div class="causal-chain">
		<span>No leading capacity signal</span><b>→</b><span>Worker over-admission</span><b>→</b><span>Local waiting</span><b>→</b><span class="tail-outcome">High P90 / P95 / P99</span>
	</div>
</div>

---

This is why mixed workloads are particularly difficult for a shared listener. The common case can keep the median looking reasonable while a smaller group of requests queues behind long CPU-bound work. That local queueing appears as high P90, P95, and P99 latency. A trailing utilization report may identify the pressure afterward, but it cannot rescue the requests already waiting inside a worker.
