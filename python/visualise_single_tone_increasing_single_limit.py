import json
import matplotlib.pyplot as plt
import math

with open('data/processed_json/single_tone_result_increasing_single_limit.json', 'r') as f:
    results = json.load(f)

fig = plt.figure()
ax1 = fig.add_subplot(111)

double_precision_series = [[],[]]
single_precision_series = [[],[]]
half_precision_series = [[],[]]
bfloat_precision_series = [[],[]]

zero_double_precision_series = [[],[]]
zero_single_precision_series = [[],[]]
zero_half_precision_series = [[],[]]
zero_bfloat_precision_series = [[],[]]

for result in results:
	if math.isnan(result["B_output"]) or math.isinf(result["B_output"]):
		if result["precision"] == "d":
			zero_double_precision_series[0].append(result["B_input"])
			zero_double_precision_series[1].append(result["B_output"])
		if result["precision"] == "f":
			zero_single_precision_series[0].append(result["B_input"])
			zero_single_precision_series[1].append(result["B_output"])
		if result["precision"] == "h":
			zero_half_precision_series[0].append(result["B_input"])
			zero_half_precision_series[1].append(result["B_output"])
		if result["precision"] == "b":
			zero_bfloat_precision_series[0].append(result["B_input"])
			zero_bfloat_precision_series[1].append(result["B_output"])
	else:
		if result["precision"] == "d":
			double_precision_series[0].append(result["B_input"])
			double_precision_series[1].append(result["B_output"])
		if result["precision"] == "f":
			single_precision_series[0].append(result["B_input"])
			single_precision_series[1].append(result["B_output"])
		if result["precision"] == "h":
			half_precision_series[0].append(result["B_input"])
			half_precision_series[1].append(result["B_output"])
		if result["precision"] == "b":
			bfloat_precision_series[0].append(result["B_input"])
			bfloat_precision_series[1].append(result["B_output"])

ax1.plot(double_precision_series[0],double_precision_series[1], c='c', marker=".", label="double")
ax1.plot(single_precision_series[0],single_precision_series[1], c='r', marker=".", label="single")
ax1.plot(half_precision_series[0],half_precision_series[1], c='g', marker=".", label="half")
ax1.plot(bfloat_precision_series[0],bfloat_precision_series[1], c='b', marker=".", label="bfloat")

ax1.annotate('Largest non-NaN/inf half output',
            xy=(half_precision_series[0][-1],half_precision_series[1][-1]), xycoords='data',
            xytext=(0.05, 0.55), textcoords='axes fraction',
            arrowprops=dict(facecolor='green', shrink=0.05),
            horizontalalignment='left', verticalalignment='top')

ax1.annotate('Largest non-NaN/inf bfloat output',
            xy=(bfloat_precision_series[0][-1],bfloat_precision_series[1][-1]), xycoords='data',
            xytext=(0.9, 0.5), textcoords='axes fraction',
            arrowprops=dict(facecolor='blue', shrink=0.05),
            horizontalalignment='right', verticalalignment='top')

ax1.annotate('Largest non-NaN/inf single output',
            xy=(single_precision_series[0][-1],single_precision_series[1][-1]), xycoords='data',
            xytext=(0.8, 0.6), textcoords='axes fraction',
            arrowprops=dict(facecolor='red', shrink=0.05),
            horizontalalignment='right', verticalalignment='top')

ax1.annotate('Largest non-NaN/inf double output',
            xy=(double_precision_series[0][-1],double_precision_series[1][-1]), xycoords='data',
            xytext=(0.5,0.95), textcoords='axes fraction',
            arrowprops=dict(facecolor='cyan', shrink=0.05),
            horizontalalignment='left', verticalalignment='top')


ax1.set_yscale('log')
ax1.set_xscale('log')
ax1.set_ylabel('Height of pertubation peak seen in FFT result')
ax1.set_xlabel('Pertubation signal amplitude')

ax1.legend(loc='upper left')
ax1.set_title('Single tone sensitivity comparison, FFT length=8192')

plt.show()