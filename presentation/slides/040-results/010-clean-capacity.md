---
template: diagram
duration: 19
section: Representative benchmark
marker: Results
transition: fade
---

# Comparable throughput before saturation

<p class="fantail-subtitle">60 workers · CPU-heavy requests · five-minute fixed-rate runs</p>

<table class="results-table">
	<thead><tr><th>Offered</th><th>Strategy</th><th>Successful RPS</th><th>200 mean</th><th>200 p99</th><th>Rejected</th></tr></thead>
	<tbody>
		<tr><td>100 RPS</td><td>Shared listener</td><td>99.98</td><td>465 ms</td><td>712 ms</td><td>0</td></tr>
		<tr class="fantail-result"><td>100 RPS</td><td>Fantail</td><td>100.00</td><td>477 ms</td><td>722 ms</td><td>0</td></tr>
		<tr><td>110 RPS</td><td>Shared listener</td><td>110.00</td><td>634 ms</td><td>1,479 ms</td><td>0</td></tr>
		<tr class="fantail-result"><td>110 RPS</td><td>Fantail</td><td>109.89</td><td>525 ms</td><td>797 ms</td><td>0.10%</td></tr>
	</tbody>
</table>

---

The goal was not to win a microbenchmark. It was to preserve the useful capacity of the existing strategy while gaining explicit scheduling control. At 100 and 110 offered requests per second, Fantail delivered equivalent successful throughput as a shared listener design.
