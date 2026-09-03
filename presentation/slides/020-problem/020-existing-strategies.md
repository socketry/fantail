---
template: diagram
duration: 30
marker: Shared Listener
transition: fade
---

<div class="fantail-slide">
	<div class="fantail-heading">
		<p class="fantail-kicker">Existing strategies</p>
		<h1>Where does excess work wait?</h1>
	</div>
	<div class="strategy-grid single-strategy">
		<div class="strategy-card">
			<h2>Shared listener</h2>
			<div class="mini-flow"><span>Client</span><b>→</b><span>Socket queue</span><b>→</b><span>Workers</span></div>
			<p>Simple, but accepting a socket is only a proxy for request-processing capacity.</p>
		</div>
	</div>
</div>

---

A shared listener naturally lets a worker that can accept a socket take the next connection, but that does not necessarily mean it can begin the request inside it. It also cannot apply rich HTTP admission policy. The queue is shared before acceptance; after acceptance, the request belongs to that worker.
