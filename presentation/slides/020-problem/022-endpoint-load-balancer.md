---
template: diagram
duration: 23
section: Existing strategies
marker: Endpoint Load Balancer
transition: fade
---

# Where does excess work wait?

<div class="strategy-grid single-strategy">
	<div class="strategy-card">
		<h2>Endpoint load balancer</h2>
		<div class="mini-flow"><span>Client</span><b>→</b><span>Connection pool</span><b>→</b><span>Worker</span></div>
		<p>A request can be committed to one worker while another worker becomes available.</p>
	</div>
</div>

---

General-purpose load balancers commonly use round-robin, least-request, or similar policies. These approximate capacity when selecting an endpoint, while utilization reported with a response is necessarily a trailing signal. Once a request is committed to an endpoint's connection pool, it often cannot be reassigned merely because another worker becomes available.
