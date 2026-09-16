---
template: diagram
duration: 22
section: Existing strategies
marker: Shared Listener
transition: fade
---

# Where does excess work wait?

<div class="strategy-grid single-strategy">
	<div class="strategy-card">
		<h2>Shared listener</h2>
		<div class="mini-flow"><span>Client</span><b>→</b><span>Socket queue</span><b>→</b><span>Workers</span></div>
		<p>Simple, but accepting a socket is only a proxy for request-processing capacity.</p>
	</div>
</div>

---

Servers commonly use a shared listener backed by an operating-system socket accept queue. This distributes connections, but accepting a connection is only a proxy for request-processing capacity. A worker can accept a connection before it knows whether it can immediately process the request inside it, creating local queueing or resource contention.
