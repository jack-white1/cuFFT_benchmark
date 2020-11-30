import matplotlib.pyplot as plt
import math
import os
import subprocess
import scipy.signal
import json

input_result = "result"
length = "8192"
datatypes = ["d","f","h","b"]

numNoiseAmplitudes = 100
repeatsPerSNR = 10

starting_noise_stdev = 1.0
starting_signal_amplitude = 1.0
noise_stdev_step = 1.0

listVals = dict.fromkeys(datatypes)
absListVals = dict.fromkeys(datatypes)
sumVals = dict.fromkeys(datatypes)
peakValsDict = dict.fromkeys(datatypes)

subprocess.run(["make"])

for datatype in datatypes:
	noise_stdev = starting_noise_stdev
	signal_amplitude = starting_signal_amplitude
	peakValsDict[datatype] = {}

	for i in range(numNoiseAmplitudes):
		peakValsDict[datatype][noise_stdev] = []
		for j in range(repeatsPerSNR):
			data_path = "data/fft_"+input_result+"_"+length+"_1_1_"+datatype+"_C2C.dat"
			if os.path.exists(data_path):
		  		os.remove(data_path)
			executable = "cuFFT_benchmark.exe"
			args = length + " 0 0 100 10 " + datatype + " C2C 0"
			subprocess.run(["./"+executable,length,"0","0","1","1",datatype,"C2C","0",str(signal_amplitude),str(noise_stdev)])

			f = open(data_path, "r")
			vals = []
			absVals = []

			for line in f:
				pair = [float(i) for i in line.split()]
				vals.append(pair)
				absVals.append(math.sqrt(float(pair[0])**2 + float(pair[1])**2))
			f.close()
			del(vals[:int(len(vals)/2)])
			del(absVals[:int(len(absVals)/2)])
			listVals[datatype]= vals
			absListVals[datatype] = absVals
			max_value = max(absListVals[datatype])
			max_index = absListVals[datatype].index(max_value)
			peakValsDict[datatype][noise_stdev].append(max_index)
			#print("max value at :", max_index)
		#print("peaks in precision " + datatype + ":" + str(scipy.signal.find_peaks(absVals, height=100)) + "\n")
		sumVals[datatype] = sum(absVals)

		noise_stdev += noise_stdev_step

with open('data.json', 'w') as fp:
    json.dump(peakValsDict, fp)

print(peakValsDict)
'''
props = dict(boxstyle='round', facecolor='wheat', alpha=0.5)

fig, axs = plt.subplots(2,2)
axs[0, 0].plot(absListVals["d"])
axs[0, 0].set_title('Double')
axs[0,0].text(0.25, 0.95, "Area under graph: "+str(sumVals["d"]), transform=axs[0,0].transAxes, fontsize=10,verticalalignment='top', bbox=props)
axs[0, 1].plot(absListVals["f"])
axs[0, 1].set_title('Float')
axs[0,1].text(0.25, 0.95, "Area under graph: "+str(sumVals["f"]), transform=axs[0,1].transAxes, fontsize=10,verticalalignment='top', bbox=props)
axs[1, 0].plot(absListVals["h"])
axs[1, 0].set_title('Half')
axs[1,0].text(0.25, 0.95, "Area under graph: "+str(sumVals["h"]), transform=axs[1,0].transAxes, fontsize=10,verticalalignment='top', bbox=props)
axs[1, 1].plot(absListVals["b"])
axs[1, 1].set_title('Bfloat16')
axs[1,1].text(0.25, 0.95, "Area under graph: "+str(sumVals["b"]), transform=axs[1,1].transAxes, fontsize=10,verticalalignment='top', bbox=props)
'''

'''
fig, axs = plt.subplots(2,2)
axs[0, 0].plot(listVals["d"])
axs[0, 0].set_title('Double')
axs[0, 1].plot(listVals["f"])
axs[0, 1].set_title('Float')
axs[1, 0].plot(listVals["h"])
axs[1, 0].set_title('Half')
axs[1, 1].plot(listVals["b"])
axs[1, 1].set_title('Bfloat16')
'''

plt.show()

'''
{
	"double" 	: {
		"signal_amplitude" : {
			"noise_stdev" : {
				"peak_locations" : [3072,3072,3072,3072]
			}
		}
	},
	"single" 	: {},
	"half"		: {},
	"bfloat16"	: {},
}
'''