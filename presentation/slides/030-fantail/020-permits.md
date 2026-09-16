---
template: diagram
duration: 12
section: Capacity model
marker: Permits
transition: fade
---

# A processing permit means a worker is ready.

<div class="lifecycle">
	<div class="lifecycle-step active"><strong>1</strong><span>Reserve worker permit</span></div>
	<div class="lifecycle-line"></div>
	<div class="lifecycle-step active"><strong>2</strong><span>Process request</span></div>
	<div class="lifecycle-line"></div>
	<div class="lifecycle-step release"><strong>3</strong><span>Response headers</span><small>release worker permit</small></div>
	<div class="lifecycle-line"></div>
	<div class="lifecycle-step stream"><strong>4</strong><span>Stream body</span><small>retain stream slot</small></div>
</div>

---

Once response processing completes, the worker can accept new work. The streaming response retains a separate permit until its body closes, bounding the number of concurrent streams.
