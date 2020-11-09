import subprocess
FNULL = open(os.devnull, 'w')
config =  "1024 0 0 1 10 f C2C 0"
args = "cuFFT_benchmark.exe " + config
subprocess.call(args, stdout=FNULL, stderr=FNULL, shell=False)