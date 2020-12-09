import matplotlib.pyplot as plt
import math
import os
import subprocess
import scipy.signal
import json
import sys
import math
from progress_bar import progress_bar

input_result = "result"
length_int = 8192
length = str(int(length_int))
datatypes = ["d","f","h","b"]



signal_A_amplitude = 0.0
start_signal_B_amplitude = 0.01
finish_signal_B_amplitude = 10**45
noise_stdev = 0.0

num_iters = 100
multiplier = math.exp(math.log(finish_signal_B_amplitude/start_signal_B_amplitude)/num_iters)

num_FFTs = num_iters * len(datatypes)
signal_B_amplitudes = []
for i in range(num_iters):
	curr_amplitude = start_signal_B_amplitude * (multiplier**i)
	signal_B_amplitudes.append(curr_amplitude)

current_working_directory = os.getcwd()

listVals = dict.fromkeys(datatypes)
absListVals = dict.fromkeys(datatypes)
sumVals = dict.fromkeys(datatypes)

subprocess.run(["make"],stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

#print("Amplitudes that are going to be tried for the secondary signal: ",signal_B_amplitudes)
results = []
counter = 0
for datatype in datatypes:
	#signal_B_amplitude = start_signal_B_amplitude
	for i in signal_B_amplitudes:
		counter+=1
		progress_bar(counter, num_FFTs)
		data_path = current_working_directory+"/data/dat_files/fft_"+input_result+"_"+length+"_1_1_" + "{:e}".format(signal_A_amplitude) + "_" +  "{:e}".format(i) +"_"+ "{:e}".format(noise_stdev)+"_"+datatype+"_C2C.dat"
		if os.path.exists(data_path):
	  		os.remove(data_path)
		executable = current_working_directory+ "/cuFFT_benchmark"
		args = length + " 0 0 100 10 " + datatype + " C2C 0"
		subprocess.run([executable,length,"0","0","1","1",datatype,"C2C","0",str(signal_A_amplitude),str(i),str(noise_stdev)],stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

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
		dual_tone_result = {"precision":datatype,"length":length_int,"A_input":signal_A_amplitude,"B_input":i,"A_output":absVals[7168],"B_output":absVals[6144],"noise_stdev":noise_stdev}
		#print("dual_tone_result: ", dual_tone_result)
		results.append(dual_tone_result)
		#print("peaks in precision " + datatype + ":" + str(scipy.signal.find_peaks(absVals, height=0)) + "\n")
		sumVals[datatype] = sum(absVals)
		#signal_B_amplitude *= multiplier



if os.path.exists('data/processed_json/dual_tone_result.json'):
	  		os.remove('data/processed_json/dual_tone_result.json')

with open('data/processed_json/dual_tone_result.json', 'w') as f:
    json.dump(results, f)
