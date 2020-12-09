import matplotlib.pyplot as plt
import math
import os
import subprocess
import scipy.signal

input_result = "result"
#length = "8192"
length = str(int(8192))
datatypes = ["d","f","h","b"]

signal_A_amplitude = 1.0
signal_B_amplitude = 0.1
noise_stdev = 0.0

current_working_directory = os.getcwd()

listVals = dict.fromkeys(datatypes)
absListVals = dict.fromkeys(datatypes)
sumVals = dict.fromkeys(datatypes)

subprocess.run(["make"])

for datatype in datatypes:
	data_path = current_working_directory+"/data/dat_files/fft_"+input_result+"_"+length+"_1_1_"+datatype+"_C2C.dat"
	if os.path.exists(data_path):
  		os.remove(data_path)
	executable = current_working_directory+ "/cuFFT_benchmark"
	args = length + " 0 0 100 10 " + datatype + " C2C 0"
	subprocess.run([executable,length,"0","0","1","1",datatype,"C2C","0",str(signal_A_amplitude),str(signal_B_amplitude),str(noise_stdev)])

	f = open(data_path, "r")
	vals = []
	absVals = []
	for line in f:
		pair = [float(i) for i in line.split()]
		vals.append(pair)
		absVals.append(math.sqrt(float(pair[0])**2 + float(pair[1])**2))
	f.close()
	#del(vals[:int(len(vals)/2)])
	#del(absVals[:int(len(absVals)/2)])
	listVals[datatype]= vals
	absListVals[datatype] = absVals
	print("peaks in precision " + datatype + ":" + str(scipy.signal.find_peaks(absVals, height=100)) + "\n")
	sumVals[datatype] = sum(absVals)

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
>clear existing data files
>run each executable
>find peaks, store their location and height
>visualise output, maybe labelling peaks
'''