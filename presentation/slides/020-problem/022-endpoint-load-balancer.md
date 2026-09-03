---
template: diagram
duration: 30
marker: Endpoint Load Balancer
transition: fade
---

<div class="fantail-slide">
	<div class="fantail-heading">
		<p class="fantail-kicker">Existing strategies</p>
		<h1>Where does excess work wait?</h1>
	</div>
	<div class="strategy-grid single-strategy">
		<div class="strategy-card">
			<h2>Endpoint load balancer</h2>
			<div class="mini-flow"><span>Client</span><b>→</b><span>Connection pool</span><b>→</b><span>Worker</span></div>
			<p>A request can be committed to one worker while another worker becomes available.</p>
		</div>
	</div>
</div>

---

General load balancers traditionally use round-robin, least-recently-used or other approaches to distributing requests. In cases where utilization is measured, it's often a trailing indicator, resulting in the poor request distribution and over-comitted workers.
