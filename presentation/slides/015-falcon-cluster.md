---
template: diagram
duration: 18
section: Deployment model
marker: Falcon Cluster
transition: fade
---

# Fantail operates in front of a Falcon cluster

<p class="fantail-subtitle">Each worker is an independently routable process with its own HTTP endpoint.</p>

<div class="supervisor-boundary">
	<div class="supervisor-label">Supervisor</div>
	<div class="cluster-topology">
		<div class="architecture-node fantail-node">
			<strong>Fantail</strong>
			<small>load balancer</small>
		</div>
		<div class="cluster-routes">
			<span>HTTP/2</span>
			<b>→</b>
		</div>
		<div class="worker-stack">
			<div class="architecture-node worker-node">Falcon worker 1 <span>:3001</span></div>
			<div class="architecture-node worker-node">Falcon worker 2 <span>:3002</span></div>
			<div class="architecture-node worker-node">Falcon worker N <span>:30xx</span></div>
		</div>
	</div>
</div>

---

Fantail operates in front of a Falcon cluster. Each worker has a distinct HTTP endpoint rather than sharing a single listener. The supervisor manages those processes, while Fantail uses their endpoints to decide which worker should receive each request.
