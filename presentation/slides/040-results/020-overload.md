---
template: diagram
duration: 23
section: At saturation
marker: Overload
transition: fade
---

# Similar throughput. Very different failure behavior.

<table class="results-table overload-table">
	<thead><tr><th>Offered</th><th>Strategy</th><th>Successful RPS</th><th>200 mean</th><th>200 p99</th><th>Overload outcome</th></tr></thead>
	<tbody>
		<tr><td>120 RPS</td><td>Shared listener</td><td>115.61</td><td>3,924 ms</td><td>4,486 ms</td><td>1,302 load-generator drops</td></tr>
		<tr class="fantail-result"><td>120 RPS</td><td>Fantail</td><td>115.28</td><td>664 ms</td><td>900 ms</td><td>1,415 HTTP 429</td></tr>
		<tr><td>130 RPS</td><td>Shared listener</td><td>113.91</td><td>4,164 ms</td><td>4,912 ms</td><td>4,763 load-generator drops + 24 timeouts</td></tr>
		<tr class="fantail-result"><td>130 RPS</td><td>Fantail</td><td>115.78</td><td>710 ms</td><td>976 ms</td><td>4,267 HTTP 429</td></tr>
	</tbody>
</table>
<p class="results-callout">Fantail rejected excess work in about 252 ms—close to its configured 250 ms queue limit.</p>

---

At saturation, successful throughput was comparable. The shared-listener path accumulated roughly four seconds of latency and eventually produced load-generator drops and timeouts. Fantail bounded queue wait and returned explicit HTTP 429 responses, keeping successful p99 latency below one second.
