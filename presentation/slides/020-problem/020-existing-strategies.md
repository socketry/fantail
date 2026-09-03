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

The most basic servers typically use shared listeners with a shared operating system socket accept queue. However, this may lead to inefficient request distribution as workers may accept more requests than it can process concurrently, leading to internal queueing or resource contention.
