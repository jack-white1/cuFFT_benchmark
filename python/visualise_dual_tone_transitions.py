import json
import matplotlib.pyplot as plt

with open('data/processed_json/dual_tone_result_double_transition.json', 'r') as f:
    double_results = json.load(f)

with open('data/processed_json/dual_tone_result_single_transition.json', 'r') as f:
    single_results = json.load(f)

with open('data/processed_json/dual_tone_result_half_transition.json', 'r') as f:
    half_results = json.load(f)

with open('data/processed_json/dual_tone_result_bfloat_transition.json', 'r') as f:
    bfloat_results = json.load(f)



double_precision_series = [[],[]]
single_precision_series = [[],[]]
half_precision_series = [[],[]]
bfloat_precision_series = [[],[]]
zero_double_precision_series = [[],[]]
zero_single_precision_series = [[],[]]
zero_half_precision_series = [[],[]]
bfloat_precision_series = [[],[]]

for result in double_results:
	if result["B_output"] != 0.0:
		if result["precision"] == "d":
			double_precision_series[0].append(result["B_input"])
			double_precision_series[1].append(result["B_output"])
	if result["B_output"] == 0.0:
		if result["precision"] == "d":
			zero_double_precision_series[0].append(result["B_input"])
			zero_double_precision_series[1].append(result["B_output"])

for result in single_results:
	if result["B_output"] != 0.0:
		if result["precision"] == "f":
			single_precision_series[0].append(result["B_input"])
			single_precision_series[1].append(result["B_output"])
	if result["B_output"] == 0.0:
		if result["precision"] == "f":
			zero_single_precision_series[0].append(result["B_input"])
			zero_single_precision_series[1].append(result["B_output"])

for result in half_results:
	if result["B_output"] != 0.0:
		if result["precision"] == "h":
			half_precision_series[0].append(result["B_input"])
			half_precision_series[1].append(result["B_output"])
	if result["B_output"] == 0.0:
		if result["precision"] == "h":
			zero_half_precision_series[0].append(result["B_input"])
			zero_half_precision_series[1].append(result["B_output"])

for result in bfloat_results:
	if result["B_output"] != 0.0:
		if result["precision"] == "b":
			bfloat_precision_series[0].append(result["B_input"])
			bfloat_precision_series[1].append(result["B_output"])
	if result["B_output"] == 0.0:
		if result["precision"] == "b":
			zero_bfloat_precision_series[0].append(result["B_input"])
			zero_bfloat_precision_series[1].append(result["B_output"])

fig, axs = plt.subplots(2,2)
axs[0,0].plot(double_precision_series[0],double_precision_series[1], c='c', marker=".", label="double")
axs[0,0].set_yscale('log')
axs[0,0].set_xscale('log')
axs[0,1].plot(single_precision_series[0],single_precision_series[1], c='r', marker=".", label="single")
axs[0,1].set_yscale('log')
axs[0,1].set_xscale('log')
axs[1,0].plot(half_precision_series[0],half_precision_series[1], c='g', marker=".", label="half")
axs[1,0].set_yscale('log')
axs[1,0].set_xscale('log')
axs[1,1].plot(bfloat_precision_series[0],bfloat_precision_series[1], c='b', marker=".", label="bfloat")
axs[1,1].set_yscale('log')
axs[1,1].set_xscale('log')



axs[0,0].set_ylabel('Height of pertubation peak seen in FFT result')
axs[0,0].set_xlabel('Pertubation signal amplitude')
axs[0,1].set_ylabel('Height of pertubation peak seen in FFT result')
axs[0,1].set_xlabel('Pertubation signal amplitude')
axs[1,0].set_ylabel('Height of pertubation peak seen in FFT result')
axs[1,0].set_xlabel('Pertubation signal amplitude')
axs[1,1].set_ylabel('Height of pertubation peak seen in FFT result')
axs[1,1].set_xlabel('Pertubation signal amplitude')

axs[0,0].legend(loc='upper left')
axs[0,1].legend(loc='upper left')
axs[1,0].legend(loc='upper left')
axs[1,1].legend(loc='upper left')

fig.suptitle('Dual tone transition comparison, FFT length=8192, primary signal amplitude=1.0')

plt.show()