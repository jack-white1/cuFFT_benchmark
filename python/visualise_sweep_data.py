import json
import os
import matplotlib.pyplot as plt

current_working_directory = os.getcwd()
datatypes = ["d","f","h","b"]

with open(current_working_directory + '/data/processed_json/sweep_data.json', 'r') as fp:
    sweep_data = json.load(fp)

result = dict.fromkeys(datatypes)


for datatype in datatypes:
	result[datatype] = {}
	for noise_stdev in sweep_data[datatype]:
		counter = 0
		for experiment in sweep_data[datatype][noise_stdev]:
			if experiment == 3072:
				counter +=1
		result[datatype][noise_stdev] = counter

print(result['b'])


plt.xticks([int(float(j)) for j in result['b'].keys()], rotation='vertical')
plt.xlabel("Noise stdev")
plt.plot(result['b'].keys(),result['b'].values(), color='red')
plt.plot(result['h'].keys(),result['h'].values(), color='blue')
plt.plot(result['f'].keys(),result['f'].values(), color='green')
plt.plot(result['d'].keys(),result['d'].values(), color='purple')
plt.show()




