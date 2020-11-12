import matplotlib.pyplot as plt
import math

input_result = "result"
length = "8192"
precision_letter = "d"

f = open("data/fft_"+input_result+"_"+length+"_1_1_"+precision_letter+"_C2C.dat", "r")

listVals = []

if ((precision_letter == "h") or (precision_letter == "b")):
	for line in f:
		listVals.append([float(i) for i in line.split()])

if ((precision_letter == "f") or (precision_letter == "d")):
	counter = 0
	current_line = []
	for line in f:
		if ((counter % 2) == 0):
			current_line = []
			current_line.append(float(line))
		if ((counter % 2) == 1):
			current_line.append(float(line))
			listVals.append(current_line)
		counter+=1 

f.close()

absListVals = []

for pair in listVals:
	absListVals.append(math.sqrt(pair[0]**2 + pair[1]**2))


plt.plot(listVals)

plt.show()