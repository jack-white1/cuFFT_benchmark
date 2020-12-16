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



start_signal_A_amplitude = 10.0
finish_signal_A_amplitude = 10e-14
start_signal_B_amplitude = 10.0
finish_signal_B_amplitude = 10e-14
noise_stdev = 0.0

num_iters = 10
multiplier_A = math.exp(math.log(finish_signal_A_amplitude/start_signal_A_amplitude)/num_iters)
multiplier_B = math.exp(math.log(finish_signal_B_amplitude/start_signal_B_amplitude)/num_iters)

num_FFTs = num_iters * num_iters * len(datatypes)
signal_A_amplitudes = []
signal_B_amplitudes = []
for i in range(num_iters):
	curr_amplitude_A = start_signal_A_amplitude * (multiplier_A**i)
	signal_A_amplitudes.append(curr_amplitude_A)
	curr_amplitude_B = start_signal_B_amplitude * (multiplier_B**i)
	signal_B_amplitudes.append(curr_amplitude_B)

current_working_directory = os.getcwd()

listVals = dict.fromkeys(datatypes)
absListVals = dict.fromkeys(datatypes)
sumVals = dict.fromkeys(datatypes)

subprocess.run(["make"],stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

results = []
counter = 0
for datatype in datatypes:
	for j in signal_A_amplitudes:
		for i in signal_B_amplitudes:
			counter+=1
			progress_bar(counter, num_FFTs)
			data_path = current_working_directory+"/data/dat_files/fft_"+input_result+"_"+length+"_1_1_" + "{:e}".format(j) + "_" +  "{:e}".format(i) +"_"+ "{:e}".format(noise_stdev)+"_"+datatype+"_C2C.dat"
			if os.path.exists(data_path):
		  		os.remove(data_path)
			executable = current_working_directory+ "/cuFFT_benchmark"
			args = length + " 0 0 100 10 " + datatype + " C2C 0"
			subprocess.run([executable,length,"0","0","1","1",datatype,"C2C","0",str(j),str(i),str(noise_stdev)],stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
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
			dual_tone_result = {"precision":datatype,"length":length_int,"A_input":j,"B_input":i,"A_output":absVals[int(length_int*0.875)],"B_output":absVals[int(length_int*0.75)],"noise_stdev":noise_stdev}
			results.append(dual_tone_result)
			sumVals[datatype] = sum(absVals)


json_path = 'data/processed_json/dual_axis_dual_tone_result_length_'+length+'_with_'+str(num_iters)+'_samples.json'

if os.path.exists(json_path):
	  		os.remove(json_path)

with open(json_path, 'w') as f:
    json.dump(results, f)
