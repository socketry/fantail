---
template: diagram
duration: 16
marker: Fantail
transition: fade
---

<div class="fantail-slide architecture-slide">
	<div class="fantail-heading">
		<p class="fantail-kicker">Fantail</p>
		<h1>Admission before assignment</h1>
	</div>
	<div class="architecture">
		<div class="architecture-node client-node">Clients</div>
		<div class="architecture-arrow">→</div>
		<div class="architecture-node edge-node">Edge proxy</div>
		<div class="architecture-arrow">→</div>
		<div class="architecture-node fantail-node">
			<strong>Fantail</strong>
			<small>global admission queue</small>
		</div>
		<div class="architecture-arrow">→</div>
		<div class="worker-stack">
			<div class="architecture-node worker-node">Worker 1 <span>permit</span></div>
			<div class="architecture-node worker-node">Worker 2 <span>permit</span></div>
			<div class="architecture-node worker-node">Worker N <span>permit</span></div>
		</div>
	</div>
	<p class="architecture-caption">HTTP/2 upstreams · dynamic endpoint registration · explicit worker capacity</p>
</div>

---

Fantail sits next to the application workers. Workers register dynamically and advertise processing permits. Fantail keeps pending requests globally assignable and dispatches one only when an eligible worker permit can be reserved.
