import matplotlib.pyplot as plt
import math
import os
import subprocess
import scipy.signal

input_result = "result"
length = "8192"
datatypes = ["d","f","h","b"]




listVals = dict.fromkeys(datatypes)
absListVals = dict.fromkeys(datatypes)

for datatype in datatypes:
	data_path = "data/fft_"+input_result+"_"+length+"_1_1_"+datatype+"_C2C.dat"
	if os.path.exists(data_path):
  		os.remove(data_path)
	executable = "cuFFT_benchmark.exe"
	args = length + " 0 0 100 10 " + datatype + " C2C 0"
	subprocess.run(["./"+executable,length,"0","0","100","10",datatype,"C2C","0"])

	f = open(data_path, "r")
	vals = []
	absVals = []
	for line in f:
		pair = [float(i) for i in line.split()]
		vals.append(pair)
		absVals.append(math.sqrt(float(pair[0])**2 + float(pair[1])**2))
	f.close()
	listVals[datatype]= vals
	absListVals[datatype] = absVals
	print("peaks in precision " + datatype + ":" + str(scipy.signal.find_peaks(absVals, height=100)) + "\n")



fig, axs = plt.subplots(2,2)
axs[0, 0].plot(absListVals["d"])
axs[0, 0].set_title('Double')
axs[0, 1].plot(absListVals["f"])
axs[0, 1].set_title('Float')
axs[1, 0].plot(absListVals["h"])
axs[1, 0].set_title('Half')
axs[1, 1].plot(absListVals["b"])
axs[1, 1].set_title('Bfloat16')


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