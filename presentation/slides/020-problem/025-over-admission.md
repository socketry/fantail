---
template: diagram
duration: 50
marker: Over-admission
transition: fade
---

<div class="fantail-slide">
	<div class="fantail-heading">
		<p class="fantail-kicker">Shared listener</p>
		<h1>Accepted does not always mean capacity.</h1>
		<p>The listener can see sockets—not the kind of work inside them or whether a worker can begin it now.</p>
	</div>
	<div class="admission-flow">
		<div class="listener-queue">
			<strong>Shared listener</strong>
			<div class="request-stack">
				<span class="request cpu">CPU</span>
				<span class="request io">I/O</span>
				<span class="request short">short</span>
			</div>
		</div>
		<div class="admission-arrow">→</div>
		<div class="worker-admission-grid">
			<div class="worker-admission busy">
				<strong>Worker A</strong>
				<span class="active-work">Long CPU task</span>
				<span class="waiting-work">accepted work waits</span>
			</div>
			<div class="worker-admission">
				<strong>Worker B</strong>
				<span class="active-work io-work">I/O wait</span>
				<span class="capacity-note">could overlap work</span>
			</div>
			<div class="worker-admission">
				<strong>Worker C</strong>
				<span class="active-work available-work">Available</span>
				<span class="capacity-note">capacity may reappear</span>
			</div>
		</div>
	</div>
	<p class="admission-caption">Once work enters a worker, it is no longer globally assignable—even if another worker becomes available first.</p>
	<div class="signal-timing">
		<div class="signal-card leading-signal">
			<strong>Leading · worker permit</strong>
			<span>Can this worker begin the request now?</span>
		</div>
		<b>versus</b>
		<div class="signal-card trailing-signal">
			<strong>Trailing · response utilization</strong>
			<span>How busy was the worker after dispatch?</span>
		</div>
	</div>
</div>

---

With a mixed workload, a worker may accept more work than it can usefully process. The shared listener makes an admission decision at the socket boundary, before it can distinguish a CPU-heavy request from work that can execute concurrently. Excess work then waits inside the chosen worker rather than remaining available to the next suitable worker, and utilization returned with the response describes what already happened; it is too late to prevent that placement. A permit based system answers the admission question before dispatch.
