---
template: diagram
duration: 40
marker: Permits
transition: fade
---

<div class="fantail-slide">
	<div class="fantail-heading">
		<p class="fantail-kicker">Capacity model</p>
		<h1>A permit represents request-processing capacity.</h1>
	</div>
	<div class="lifecycle">
		<div class="lifecycle-step active"><strong>1</strong><span>Reserve permit</span></div>
		<div class="lifecycle-line"></div>
		<div class="lifecycle-step active"><strong>2</strong><span>Process request</span></div>
		<div class="lifecycle-line"></div>
		<div class="lifecycle-step release"><strong>3</strong><span>Response headers</span><small>release permit</small></div>
		<div class="lifecycle-line"></div>
		<div class="lifecycle-step stream"><strong>4</strong><span>Stream body</span><small>retain stream permit</small></div>
	</div>
</div>

---

Once response processing completes, the worker can accept new work. The streaming response retains a separate permit until its body closes, bounding the number of concurrent streams.
