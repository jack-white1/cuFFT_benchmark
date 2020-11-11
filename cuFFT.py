import os
import subprocess
import matplotlib.pyplot as plt

FNULL = open(os.devnull, 'w')

Nx = "1024"
Ny = "0"
Nz = "0"
N_FFTs = "1"
N_runs = "1"
precision = "b"
FFT_type = "C2C"
device_id = "0"
config = " "+Nx+" "+Ny+" "+Nz+" "+N_FFTs+" "+N_runs+" "+precision+" "+FFT_type+" "+device_id

args = "cuFFT_benchmark.exe" + config
subprocess.call(args, stdout=FNULL, stderr=FNULL, shell=True)