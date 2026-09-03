---
template: diagram
duration: 45
marker: Queue Policy
transition: fade
---

<div class="fantail-slide">
	<div class="fantail-heading">
		<p class="fantail-kicker">Application policy</p>
		<h1>Different requests can ask different questions.</h1>
	</div>
	<div class="queue-grid">
		<div class="queue-card cpu-queue">
			<h2>CPU-heavy</h2>
			<p>Spread across idle workers</p>
			<code>balance :spread</code>
		</div>
		<div class="queue-card io-queue">
			<h2>I/O-heavy</h2>
			<p>Prefer compatible affinity</p>
			<code>balance :pack, affinity: :grpc</code>
		</div>
		<div class="queue-card shed-queue">
			<h2>Overload</h2>
			<p>Bound queue depth and time</p>
			<code>wait_limit 0.25</code>
		</div>
	</div>
	<p class="queue-caption">Queues express preference and admission policy. The central scheduler remains work-conserving.</p>
</div>

---

Fantail can classify requests into queues. A queue can express backend eligibility, soft affinity, admission limits, and its shedding response. Preferences never reserve capacity independently: if the preferred worker is unavailable, another eligible worker can run the request.
