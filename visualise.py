import matplotlib.pyplot as plt
import math

input_result = "result"
length = "8192"
datatypes = ["d","f","h","b"]
listVals = dict.fromkeys(datatypes)

for datatype in datatypes:
	vals = [] 
	f = open("data/fft_"+input_result+"_"+length+"_1_1_"+datatype+"_C2C.dat", "r")
	for line in f:
		vals.append([float(i) for i in line.split()])
	f.close()
	listVals[datatype]= vals


fig, axs = plt.subplots(2,2)
axs[0, 0].plot(listVals["d"])
axs[0, 0].set_title('Double')
axs[0, 1].plot(listVals["f"])
axs[0, 1].set_title('Float')
axs[1, 0].plot(listVals["h"])
axs[1, 0].set_title('Half')
axs[1, 1].plot(listVals["b"])
axs[1, 1].set_title('Bfloat16')

plt.show()