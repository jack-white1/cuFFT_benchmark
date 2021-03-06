#include <iostream>
#include <fstream>
#include <vector>
#include <random>


#include <cufft.h>
#include <cuda.h>
#include <cuda_runtime.h>
#include <cuda_runtime_api.h>
#include "debug.h"
#include "timer.h"
#include "utils_cuda.h"

#include <cufftXt.h>
#include <cuda_fp16.h>
#include <cuda_bf16.h>


#include "FFT_clases.h"
#include "params.h"


template<class FFT_precision_type> class FFT_Memory {
public:
	FFT_precision_type *h_input;
	FFT_precision_type *h_output;
	FFT_precision_type *d_input;
	FFT_precision_type *d_output;
	
	FFT_Memory() {
		h_input = NULL;
		h_output = NULL;
		d_input = NULL;
		d_output = NULL;

	}
	
	float Arbitrary_function(float f1, float f2, float a1, float a2, float n1, float f){
		//return a1*sin(2.0*3.141592654*f1*f*0.99123123);
		//return a1*sin(2.0*3.141592654*f1*f) + a2*sin(2.0*3.141592654*f2*f) + 0.1245*a1*sin(2.0*3.141592654*0.354245*f1*f) + 0.5487*a2*sin(2.0*3.141592654*0.1124457*f2*f) + (3.0*3.141592654)/4.0;
		std::random_device rand_dev;
		std::mt19937 generator(rand_dev());
		std::normal_distribution<double> distribution(0.0,n1);
		return (distribution(generator)) + a1*sin(2.0*3.141592654*f1*f);
	}

	int Allocate(size_t total_input_FFT_size, size_t total_output_FFT_size, int FFT_host_to_device, int FFT_inplace){
		cudaError_t err_code;
		size_t GPU_input_size = total_input_FFT_size;
		if(FFT_inplace==1 && total_input_FFT_size<total_output_FFT_size) GPU_input_size = total_output_FFT_size;
		
		// Device allocations
		err_code = cudaMalloc((void **) &d_input,  GPU_input_size);
		if(err_code!=cudaSuccess) {printf("\nError in allocation of the device memory!\n"); return(1);}
		if(FFT_inplace==0){
			err_code = cudaMalloc((void **) &d_output, total_output_FFT_size);
			if(err_code!=cudaSuccess) {printf("\nError in allocation of the device memory!\n"); return(1);}
		}
		
		// Host allocations
		if(FFT_host_to_device==1){
			h_input 	= (FFT_precision_type *)malloc(total_input_FFT_size);
			if(h_input==NULL) {printf("\nError in allocation of the host memory!\n"); return(1);}
			h_output 	= (FFT_precision_type *)malloc(total_output_FFT_size);
			if(h_output==NULL) {printf("\nError in allocation of the host memory!\n"); return(1);}
		}
		
		if(DEBUG){
			printf("--- DEBUG memory allocation ---\n");
			printf("GPU input size: %zu; I:%zu; O:%zu;\n", GPU_input_size, total_input_FFT_size, total_output_FFT_size);
			printf("Host: I:%p; O:%p;\n", h_input, h_output);
			printf("Device: I:%p; O:%p;\n", d_input, d_output);
			printf("-------------------------------<\n");
		}
		
		return(0);
	}
	
	int Generate_data_host(size_t input_nElements){
		srand(time(NULL));
		for(size_t f=0; f<input_nElements; f++) {
			h_input[f] = rand()/(float)RAND_MAX;
		}
		return(0);
	}

	int Generate_data_C2C_host(size_t input_nElements, float signal_amplitude, float noise_stdev){
		srand(time(NULL));
		#ifdef EXPORT
			float f1,f2,a1,a2,n1;
			f1=1.0/8.0; f2=2.0/8.0; a1=signal_amplitude; a2=0.5; n1=noise_stdev;
			for(size_t f=0; f<input_nElements; f++) {
				//h_input[f].x = a1*sin(2.0*3.141592654*f1*f) + a2*sin(2.0*3.141592654*f2*f) + 0.1245*a1*sin(2.0*3.141592654*0.354245*f1*f) + 0.5487*a2*sin(2.0*3.141592654*0.1124457*f2*f) + (3.0*3.141592654)/4.0;
				h_input[f].x = Arbitrary_function(f1,f2,a1,a2,n1,f);
				h_input[f].y = 0;
			}
		#else
			for(size_t f=0; f<input_nElements; f++) {
				h_input[f].x = rand()/(float)RAND_MAX;
				h_input[f].y = rand()/(float)RAND_MAX;
			}
		#endif
		return(0);
	}

	int Generate_data_R2C_host(size_t input_nElements, float signal_amplitude, float noise_stdev){
		srand(time(NULL));
		#ifdef EXPORT
			float f1, f2, a1, a2, n1;
			f1=1.0/8.0; f2=2.0/8.0; a1=signal_amplitude; a2=0.5; n1=noise_stdev;

			for(size_t f=0; f<input_nElements; f++) {
				//h_input[f] = a1*sin(2.0*3.141592654*f1*f) + a2*sin(2.0*3.141592654*f2*f) + 0.1245*a1*sin(2.0*3.141592654*0.354245*f1*f) + 0.5487*a2*sin(2.0*3.141592654*0.1124457*f2*f) + (3.0*3.141592654)/4.0;
				h_input[f] = Arbitrary_function(f1,f2,a1,a2,n1,f);
			}
		#else
			for(size_t f=0; f<input_nElements; f++){
				h_input[f] = rand()/(float)RAND_MAX;
			}
		#endif
		return(0);
	}

	int Generate_data_C2R_host(size_t input_nElements, float signal_amplitude, float noise_stdev){
		srand(time(NULL));
		for(size_t f=0; f<input_nElements*2; f++) {
			h_input[f] = rand()/(float)RAND_MAX;
		}
		return(0);
	}

	int Generate_data_C2C_host_half(size_t input_nElements, float signal_amplitude, float noise_stdev){
		srand(time(NULL));
		#ifdef EXPORT
			float f1,f2,a1,a2,n1;
			f1=1.0/8.0; f2=2.0/8.0; a1=signal_amplitude; a2=0.5; n1=noise_stdev;
	
			for(size_t f=0; f<input_nElements; f++) {
				//h_input[f].x = __float2half(a1*sin(2.0*3.141592654*f1*f) + a2*sin(2.0*3.141592654*f2*f) + 0.1245*a1*sin(2.0*3.141592654*0.354245*f1*f) + 0.5487*a2*sin(2.0*3.141592654*0.1124457*f2*f) + (3.0*3.141592654)/4.0);
				h_input[f].x = __float2half(Arbitrary_function(f1,f2,a1,a2,n1,f));
				h_input[f].y = __float2half(0.0);
			}
		#else
			for(size_t f=0; f<input_nElements; f++) {
				h_input[f].x = __float2half(rand()/(float)RAND_MAX);
				h_input[f].y = __float2half(0.0);
			}
		#endif
		//printf("Finished\n");
		return(0);
	}

	int Generate_data_C2R_host_half(size_t input_nElements, float signal_amplitude, float noise_stdev){
		srand(time(NULL));
		for(size_t f=0; f<input_nElements*2; f++) {
			h_input[f].x = __float2half(rand()/(float)RAND_MAX);
		}
		return(0);
	}

	int Generate_data_R2C_host_half(size_t input_nElements, float signal_amplitude, float noise_stdev){
		srand(time(NULL));
		for(size_t f=0; f<(input_nElements/2); f++) {
			h_input[f].x = __float2half(rand()/(float)RAND_MAX);
		}
		return(0);
	}
	
	int Generate_data_C2C_host_bfloat16(size_t input_nElements, float signal_amplitude, float noise_stdev){
		srand(time(NULL));
		#ifdef EXPORT
			float f1,f2,a1,a2,n1;
			f1=1.0/8.0; f2=2.0/8.0; a1=signal_amplitude; a2=0.5; n1=noise_stdev;
	
			for(size_t f=0; f<input_nElements; f++) {
				//h_input[f].x = __float2bfloat16(a1*sin(2.0*3.141592654*f1*f) + a2*sin(2.0*3.141592654*f2*f) + 0.1245*a1*sin(2.0*3.141592654*0.354245*f1*f) + 0.5487*a2*sin(2.0*3.141592654*0.1124457*f2*f) + (3.0*3.141592654)/4.0);
				h_input[f].x = __float2bfloat16(Arbitrary_function(f1,f2,a1,a2,n1,f));
				h_input[f].y = __float2bfloat16(0.0);
			}
		#else
			for(size_t f=0; f<input_nElements; f++) {
				h_input[f].x = __float2bfloat16(rand()/(float)RAND_MAX);
				h_input[f].y = __float2bfloat16(0.0);
			}
		#endif
		//printf("Finished\n");
		return(0);
	}

	int Generate_data_C2R_host_bfloat16(size_t input_nElements, float signal_amplitude, float noise_stdev){
		srand(time(NULL));
		for(size_t f=0; f<input_nElements*2; f++) {
			h_input[f].x = __float2bfloat16(rand()/(float)RAND_MAX);
		}
		return(0);
	}

	int Generate_data_R2C_host_bfloat16(size_t input_nElements, float signal_amplitude, float noise_stdev){
		srand(time(NULL));
		for(size_t f=0; f<(input_nElements/2); f++) {
			h_input[f].x = __float2bfloat16(rand()/(float)RAND_MAX);
		}
		return(0);
	}

	/*int Generate_data_host_half(size_t input_nElements){
		srand(time(NULL));
		#ifdef EXPORT
			float f1,f2,a1,a2;
			f1=1.0/64.0; f2=2.0/8.0; a1=1.0; a2=0.5;
	
			for(size_t f=0; f<input_nElements; f++) {
				//h_input[f].x = __float2half(a1*sin(2.0*3.141592654*f1*f) + a2*sin(2.0*3.141592654*f2*f) + 0.1245*a1*sin(2.0*3.141592654*0.354245*f1*f) + 0.5487*a2*sin(2.0*3.141592654*0.1124457*f2*f) + (3.0*3.141592654)/4.0);
				h_input[f].x = __float2half(a1*sin(2.0*3.141592654*f1*f));

				h_input[f].y = __float2half(0.0);
			}
		#else
			for(size_t f=0; f<input_nElements; f++) {
				h_input[f].x = __float2half(rand()/(float)RAND_MAX);
				h_input[f].y = __float2half(0.0);
			}
		#endif
		printf("Finished\n");
		return(0);
	}

	int Generate_data_host_bfloat16(size_t input_nElements){
		srand(time(NULL));
		#ifdef EXPORT
			float f1,f2,a1,a2;
			f1=1.0/864.0; f2=2.0/8.0; a1=1.0; a2=0.5;
	
			for(size_t f=0; f<input_nElements; f++) {
				//h_input[f].x = __float2bfloat16(a1*sin(2.0*3.141592654*f1*f) + a2*sin(2.0*3.141592654*f2*f) + 0.1245*a1*sin(2.0*3.141592654*0.354245*f1*f) + 0.5487*a2*sin(2.0*3.141592654*0.1124457*f2*f) + (3.0*3.141592654)/4.0);
				h_input[f].x = __float2bfloat16(a1*sin(2.0*3.141592654*f1*f));
				h_input[f].y = __float2bfloat16(0.0);
			}
		#else
			for(size_t f=0; f<input_nElements; f++) {
				h_input[f].x = __float2bfloat16(rand()/(float)RAND_MAX);
				h_input[f].y = __float2bfloat16(0.0);
			}
		#endif
		printf("Finished\n");
		return(0);
	}*/
	
	int Generate_data_device(){
		return(0);
	}
	
	int Generate_data(size_t input_nElements, int FFT_host_to_device){
		if(FFT_host_to_device==1) {
			Generate_data_host(input_nElements);
		}
		else {
			Generate_data_device();
		}
		return(0);
	}
	
	int Transfer_input(size_t total_input_FFT_size, int FFT_host_to_device, double *transfer_time){
		GpuTimer timer;
		if(FFT_host_to_device==1) {
			timer.Start();
			checkCudaErrors(cudaMemcpy(d_input, h_input, total_input_FFT_size, cudaMemcpyHostToDevice));
			timer.Stop();
			*transfer_time += timer.Elapsed();
		}
		return(0);
	}
	
	int Transfer_output(size_t total_output_FFT_size, int FFT_host_to_device, int FFT_inplace, double *transfer_time){
		GpuTimer timer;
		if(FFT_host_to_device==1) {
			timer.Start();
			if(FFT_inplace) {
				checkCudaErrors(cudaMemcpy((float *) h_output, d_input, total_output_FFT_size, cudaMemcpyDeviceToHost));
			}
			else {
				checkCudaErrors(cudaMemcpy((float *) h_output, d_output, total_output_FFT_size, cudaMemcpyDeviceToHost));
			}
			timer.Stop();
			*transfer_time += timer.Elapsed();
		}
		return(0);
	}
	
	void writeout(nv_bfloat162 value, std::ofstream &FILEOUT) {
		FILEOUT << (double) __bfloat162float(value.x) << " " << (double) __bfloat162float(value.y) << std::endl;
	}

	void writeout(half2 value, std::ofstream &FILEOUT) {
		FILEOUT << (double) __half2float(value.x) << " " << (double) __half2float(value.y) << std::endl;
	}
	
	void writeout(float2 value, std::ofstream &FILEOUT) {
		FILEOUT << (double) value.x << " " << (double) value.y << std::endl;
	}
	
	void writeout(double2 value, std::ofstream &FILEOUT) {
		FILEOUT << (double) value.x << " " << (double) value.y << std::endl;
	}
	
	void writeout(nv_bfloat16 value, std::ofstream &FILEOUT) {
		FILEOUT << (double) __bfloat162float(value) << std::endl;
	}
	
	void writeout(half value, std::ofstream &FILEOUT) {
		FILEOUT << (double) __half2float(value) << std::endl;
	}
	
	void writeout(float value, std::ofstream &FILEOUT) {
		FILEOUT << (double) value << std::endl;
	}
	
	void writeout(double value, std::ofstream &FILEOUT) {
		FILEOUT << (double) value << std::endl;
	}
	
	int Export_fft_result(FFT_Configuration fft_config, FFT_Lengths fft_params, const char precision_type = 'f'){
		char str[200];
		sprintf(str,"data/dat_files/fft_result_%zu_%zu_%zu", fft_params.Nx, fft_params.Ny, fft_params.Nz);
		if(precision_type == 'b') {sprintf(str,"%s_b",str);}
		else {
			if(fft_config.FFT_precision==FFT_PRECISION_DOUBLE) sprintf(str,"%s_d",str);
			if(fft_config.FFT_precision==FFT_PRECISION_FLOAT) sprintf(str,"%s_f",str);
			if(fft_config.FFT_precision==FFT_PRECISION_HALF) sprintf(str,"%s_h",str);
			}
		if(fft_config.FFT_type==FFT_TYPE_C2C) sprintf(str,"%s_C2C.dat",str);
		if(fft_config.FFT_type==FFT_TYPE_R2C) sprintf(str,"%s_R2C.dat",str);
		if(fft_config.FFT_type==FFT_TYPE_C2R) sprintf(str,"%s_C2R.dat",str);
		if(DEBUG){printf("%s\n", str);}
		
		int nElements = fft_params.Nx*fft_params.Ny*fft_params.Nz;
		std::ofstream FILEOUT;
		FILEOUT.open(str);
		if (!FILEOUT.fail()){
			for(int f = 0; f < nElements; f++){
				writeout(h_output[f], FILEOUT);
			}
		}
		else {
			return(1);
		}
		FILEOUT.close();
		return(0);
	}
	
	
	int Export_fft_input(FFT_Configuration fft_config, FFT_Lengths fft_params, const char precision_type = 'f'){
		char str[200];
		sprintf(str,"data/dat_files/fft_input_%zu_%zu_%zu", fft_params.Nx, fft_params.Ny, fft_params.Nz);
		if(precision_type == 'b') {sprintf(str,"%s_b",str);}
		else {
			if(fft_config.FFT_precision==FFT_PRECISION_DOUBLE) sprintf(str,"%s_d",str);
			if(fft_config.FFT_precision==FFT_PRECISION_FLOAT) sprintf(str,"%s_f",str);
			if(fft_config.FFT_precision==FFT_PRECISION_HALF) sprintf(str,"%s_h",str);
		}
		if(fft_config.FFT_type==FFT_TYPE_C2C) sprintf(str,"%s_C2C.dat",str);
		if(fft_config.FFT_type==FFT_TYPE_R2C) sprintf(str,"%s_R2C.dat",str);
		if(fft_config.FFT_type==FFT_TYPE_C2R) sprintf(str,"%s_C2R.dat",str);
		
		if(DEBUG){printf("%s\n", str);}
		
		int nElements = fft_params.Nx*fft_params.Ny*fft_params.Nz;
		std::ofstream FILEOUT;
		FILEOUT.open(str);
		if (!FILEOUT.fail()){
			for(int f = 0; f < nElements; f++){
				writeout(h_input[f], FILEOUT);
			}
		}
		else {
			return(1);
		}
		FILEOUT.close();
		return(0);
	}
	
	~FFT_Memory() {
		if(h_input!=NULL) free(h_input);
		if(h_output!=NULL) free(h_output);
		if(d_input!=NULL) cudaFree(d_input);
		if(d_output!=NULL) cudaFree(d_output);
	}
};

	
int Initiate_device(int device){
	int devCount;
	cudaGetDeviceCount(&devCount);
	if(device<devCount) {
		cudaSetDevice(device);
		return(0);
	}
	else return(1);	
}

int Check_free_memory(size_t total_input_FFT_size, size_t total_output_FFT_size){
	cudaError_t err_code;
	size_t free_mem, total_mem;
	err_code = cudaMemGetInfo(&free_mem,&total_mem);
	if(err_code!=cudaSuccess) {
		printf("CUDA ERROR!\n");
		return(1);
	}
	
	if(free_mem<(total_input_FFT_size+total_output_FFT_size)) {
		printf("ERROR: Not enough GPU memory\n");
		return(1);
	}
	
	return(0);
}

double stdev(std::vector<double> *times, double mean_time){
	double sum = 0;
	for(size_t i=0; i<times->size(); i++){
		double x = (times->operator[](i)-mean_time);
		sum = sum + x*x;
	}
	double stdev = sqrt( sum/((double) times->size()) );
	return(stdev);
}

// ***********************************************************************************
// ***********************************************************************************
// ***********************************************************************************


int cuFFT_1D_C2C_bfloat16(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<nv_bfloat162> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data_C2C_host_bfloat16(FFT_size.input_nElements, signal_amplitude, noise_stdev);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	cuFFT_error = cufftCreate(&plan);
	if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftCreate()\n", cuFFT_error); return(1);}
	long long int rank = 1;
	long long int n[1]; n[0]=FFT_lengths.Nx;
	long long int nembed[1]; nembed[0]=FFT_lengths.Nx;
	long long int stride = 1;
	long long int dist = FFT_lengths.Nx;
	size_t workSize = 0;
	cuFFT_error = cufftXtMakePlanMany(plan, rank, n, nembed, stride, dist, CUDA_C_16BF, nembed, stride, dist, CUDA_C_16BF, nFFTs, &workSize, CUDA_C_16BF);
	if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftXtMakePlanMany()\n", cuFFT_error); return(1);}
	std::vector<double> times;
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cuFFT_error = cufftXtExec(plan, FFT_mem.d_input, FFT_mem.d_output, CUFFT_FORWARD);
			if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftXtExec()\n", cuFFT_error); return(1);}
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	const char precision_type = 'b';
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths, precision_type);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths, precision_type);
	#endif 
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_1D_R2C_bfloat16(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<nv_bfloat162> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data_R2C_host_bfloat16(FFT_size.input_nElements/2, signal_amplitude, noise_stdev);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	cuFFT_error = cufftCreate(&plan);
	if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftCreate()\n", cuFFT_error); return(1);}
	long long int rank = 1;
	long long int n[1]; n[0]=FFT_lengths.Nx;
	long long int nembed[1]; nembed[0]=FFT_lengths.Nx;
	long long int stride = 1;
	long long int dist = FFT_lengths.Nx;
	size_t workSize = 0;
	cuFFT_error = cufftXtMakePlanMany(plan, rank, n, nembed, stride, dist, CUDA_R_16BF, nembed, stride, dist, CUDA_C_16BF, nFFTs, &workSize, CUDA_C_16BF);
	if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftXtMakePlanMany()\n", cuFFT_error); return(1);}
	std::vector<double> times;
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cuFFT_error = cufftXtExec(plan, FFT_mem.d_input, FFT_mem.d_output, CUFFT_FORWARD);
			if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftXtExec()\n", cuFFT_error); return(1);}
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	const char precision_type = 'b';
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths, precision_type);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths, precision_type);
		
	#endif 
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_1D_C2R_bfloat16(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<nv_bfloat162> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data_C2R_host_bfloat16(FFT_size.input_nElements/2, signal_amplitude, noise_stdev);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	cuFFT_error = cufftCreate(&plan);
	if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftCreate()\n", cuFFT_error); return(1);}
	long long int rank = 1;
	long long int n[1]; n[0]=FFT_lengths.Nx;
	long long int nembed[1]; nembed[0]=FFT_lengths.Nx;
	long long int stride = 1;
	long long int dist = FFT_lengths.Nx;
	size_t workSize = 0;
	cuFFT_error = cufftXtMakePlanMany(plan, rank, n, nembed, stride, dist, CUDA_C_16BF, nembed, stride, dist, CUDA_R_16BF, nFFTs, &workSize, CUDA_C_16BF);
	if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftXtMakePlanMany()\n", cuFFT_error); return(1);}
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cuFFT_error = cufftXtExec(plan, FFT_mem.d_input, FFT_mem.d_output, CUFFT_INVERSE);
			if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftXtExec()\n", cuFFT_error); return(1);}
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	const char precision_type = 'b';
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths, precision_type);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths, precision_type);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_1D_C2C_half(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<half2> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data_C2C_host_half(FFT_size.input_nElements, signal_amplitude, noise_stdev);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	cuFFT_error = cufftCreate(&plan);
	if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftCreate()\n", cuFFT_error); return(1);}
	long long int rank = 1;
	long long int n[1]; n[0]=FFT_lengths.Nx;
	long long int nembed[1]; nembed[0]=FFT_lengths.Nx;
	long long int stride = 1;
	long long int dist = FFT_lengths.Nx;
	size_t workSize = 0;
	cuFFT_error = cufftXtMakePlanMany(plan, rank, n, nembed, stride, dist, CUDA_C_16F, nembed, stride, dist, CUDA_C_16F, nFFTs, &workSize, CUDA_C_16F);
	if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftXtMakePlanMany()\n", cuFFT_error); return(1);}
	// cudaDataType could be following:
	// CUDA_R_16F  16 bit real 
	// CUDA_C_16F  16 bit complex
	// CUDA_R_32F  32 bit real
	// CUDA_C_32F  32 bit complex
	// CUDA_R_64F  64 bit real
	// CUDA_C_64F  64 bit complex
	// CUDA_R_8I    8 bit real as a signed integer 
	// CUDA_C_8I    8 bit complex as a pair of signed integers
	// CUDA_R_8U    8 bit real as a signed integer 
	// CUDA_C_8U    8 bit complex as a pair of signed integers
	std::vector<double> times;
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cuFFT_error = cufftXtExec(plan, FFT_mem.d_input, FFT_mem.d_output, CUFFT_FORWARD);
			if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftXtExec()\n", cuFFT_error); return(1);}
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif 
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_1D_R2C_half(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<half2> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data_R2C_host_half(FFT_size.input_nElements/2, signal_amplitude, noise_stdev);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	cuFFT_error = cufftCreate(&plan);
	if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftCreate()\n", cuFFT_error); return(1);}
	long long int rank = 1;
	long long int n[1]; n[0]=FFT_lengths.Nx;
	long long int nembed[1]; nembed[0]=FFT_lengths.Nx;
	long long int stride = 1;
	long long int dist = FFT_lengths.Nx;
	size_t workSize = 0;
	cuFFT_error = cufftXtMakePlanMany(plan, rank, n, nembed, stride, dist, CUDA_R_16F, nembed, stride, dist, CUDA_C_16F, nFFTs, &workSize, CUDA_C_16F);
	if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftXtMakePlanMany()\n", cuFFT_error); return(1);}
	std::vector<double> times;
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cuFFT_error = cufftXtExec(plan, FFT_mem.d_input, FFT_mem.d_output, CUFFT_FORWARD);
			if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftXtExec()\n", cuFFT_error); return(1);}
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif 
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_1D_C2R_half(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<half2> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data_C2R_host_half(FFT_size.input_nElements/2, signal_amplitude, noise_stdev);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	cuFFT_error = cufftCreate(&plan);
	if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftCreate()\n", cuFFT_error); return(1);}
	long long int rank = 1;
	long long int n[1]; n[0]=FFT_lengths.Nx;
	long long int nembed[1]; nembed[0]=FFT_lengths.Nx;
	long long int stride = 1;
	long long int dist = FFT_lengths.Nx;
	size_t workSize = 0;
	cuFFT_error = cufftXtMakePlanMany(plan, rank, n, nembed, stride, dist, CUDA_C_16F, nembed, stride, dist, CUDA_R_16F, nFFTs, &workSize, CUDA_C_16F);
	if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftXtMakePlanMany()\n", cuFFT_error); return(1);}
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cuFFT_error = cufftXtExec(plan, FFT_mem.d_input, FFT_mem.d_output, CUFFT_INVERSE);
			if (CUFFT_SUCCESS != cuFFT_error) {printf("Error %d in cufftXtExec()\n", cuFFT_error); return(1);}
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}


int cuFFT_1D_C2C_float(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<float2> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data_C2C_host(FFT_size.input_nElements, signal_amplitude, noise_stdev);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	cuFFT_error = cufftPlan1d(&plan, FFT_lengths.Nx, CUFFT_C2C, FFT_lengths.nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecC2C(plan, (cufftComplex *) FFT_mem.d_input, (cufftComplex *) FFT_mem.d_output, CUFFT_FORWARD);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_1D_R2C_float(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<float> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data_R2C_host(FFT_size.input_nElements, signal_amplitude, noise_stdev);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	cuFFT_error = cufftPlan1d(&plan, FFT_lengths.Nx, CUFFT_R2C, FFT_lengths.nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecR2C(plan, FFT_mem.d_input, (cufftComplex *) FFT_mem.d_output);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_1D_C2R_float(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<float> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data_C2R_host(FFT_size.input_nElements, signal_amplitude, noise_stdev);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	cuFFT_error = cufftPlan1d(&plan, FFT_lengths.Nx, CUFFT_C2R, FFT_lengths.nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecC2R(plan, (cufftComplex *) FFT_mem.d_input, FFT_mem.d_output);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}


int cuFFT_1D_C2C_double(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<double2> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data_C2C_host(FFT_size.input_nElements, signal_amplitude, noise_stdev);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	cuFFT_error = cufftPlan1d(&plan, FFT_lengths.Nx, CUFFT_Z2Z, FFT_lengths.nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecZ2Z(plan, (cufftDoubleComplex *) FFT_mem.d_input, (cufftDoubleComplex *) FFT_mem.d_output, CUFFT_FORWARD);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_1D_R2C_double(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<double> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data_R2C_host(FFT_size.input_nElements, signal_amplitude, noise_stdev);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	cuFFT_error = cufftPlan1d(&plan, FFT_lengths.Nx, CUFFT_D2Z, FFT_lengths.nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecD2Z(plan, FFT_mem.d_input, (cufftDoubleComplex *) FFT_mem.d_output);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_1D_C2R_double(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<double> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data_C2R_host(FFT_size.input_nElements, signal_amplitude, noise_stdev);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	cuFFT_error = cufftPlan1d(&plan, FFT_lengths.Nx, CUFFT_Z2D, FFT_lengths.nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecZ2D(plan, (cufftDoubleComplex *) FFT_mem.d_input, FFT_mem.d_output);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

// ***********************************************************************************
// ***********************************************************************************
// ***********************************************************************************


int cuFFT_2D_C2C_float(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<float> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data(FFT_size.input_nElements*2, FFT_conf.FFT_host_to_device);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	int rank = 2;
	int n[2]; n[0]=FFT_lengths.Ny; n[1]=FFT_lengths.Nx;
	int nembed[2]; nembed[0]=FFT_lengths.Ny; nembed[1]=FFT_lengths.Nx;
	int stride = 1;
	int dist =FFT_lengths.Nx*FFT_lengths.Ny;
	cuFFT_error = cufftPlanMany(&plan, rank, n, nembed, stride, dist, nembed, stride, dist, CUFFT_C2C, nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecC2C(plan, (cufftComplex *) FFT_mem.d_input, (cufftComplex *) FFT_mem.d_output, CUFFT_FORWARD);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_2D_R2C_float(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<float> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data(FFT_size.input_nElements, FFT_conf.FFT_host_to_device);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	int rank = 2;
	int n[2]; n[0]=FFT_lengths.Ny; n[1]=FFT_lengths.Nx;
	int nembed[2]; nembed[0]=FFT_lengths.Ny; nembed[1]=FFT_lengths.Nx;
	int stride = 1;
	int dist =FFT_lengths.Nx*FFT_lengths.Ny;
	cuFFT_error = cufftPlanMany(&plan, rank, n, nembed, stride, dist, nembed, stride, dist, CUFFT_R2C, nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecR2C(plan, FFT_mem.d_input, (cufftComplex *) FFT_mem.d_output);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_2D_C2R_float(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<float> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data(FFT_size.input_nElements*2, FFT_conf.FFT_host_to_device);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	int rank = 2;
	int n[2]; n[0]=FFT_lengths.Ny; n[1]=FFT_lengths.Nx;
	int nembed[2]; nembed[0]=FFT_lengths.Ny; nembed[1]=FFT_lengths.Nx;
	int stride = 1;
	int dist = FFT_lengths.Nx*FFT_lengths.Ny;
	cuFFT_error = cufftPlanMany(&plan, rank, n, nembed, stride, dist, nembed, stride, dist, CUFFT_C2R, nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecC2R(plan, (cufftComplex *) FFT_mem.d_input, FFT_mem.d_output);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}


int cuFFT_2D_C2C_double(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<double> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data(FFT_size.input_nElements*2, FFT_conf.FFT_host_to_device);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	int rank = 2;
	int n[2]; n[0]=FFT_lengths.Ny; n[1]=FFT_lengths.Nx;
	int nembed[2]; nembed[0]=FFT_lengths.Ny; nembed[1]=FFT_lengths.Nx;
	int stride = 1;
	int dist =FFT_lengths.Nx*FFT_lengths.Ny;
	cuFFT_error = cufftPlanMany(&plan, rank, n, nembed, stride, dist, nembed, stride, dist, CUFFT_Z2Z, nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecZ2Z(plan, (cufftDoubleComplex *) FFT_mem.d_input, (cufftDoubleComplex *) FFT_mem.d_output, CUFFT_FORWARD);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_2D_R2C_double(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<double> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data(FFT_size.input_nElements, FFT_conf.FFT_host_to_device);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
		int rank = 2;
	int n[2]; n[0]=FFT_lengths.Ny; n[1]=FFT_lengths.Nx;
	int nembed[2]; nembed[0]=FFT_lengths.Ny; nembed[1]=FFT_lengths.Nx;
	int stride = 1;
	int dist =FFT_lengths.Nx*FFT_lengths.Ny;
	cuFFT_error = cufftPlanMany(&plan, rank, n, nembed, stride, dist, nembed, stride, dist, CUFFT_D2Z, nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecD2Z(plan, FFT_mem.d_input, (cufftDoubleComplex *) FFT_mem.d_output);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_2D_C2R_double(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<double> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data(FFT_size.input_nElements*2, FFT_conf.FFT_host_to_device);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	int rank = 2;
	int n[2]; n[0]=FFT_lengths.Ny; n[1]=FFT_lengths.Nx;
	int nembed[2]; nembed[0]=FFT_lengths.Ny; nembed[1]=FFT_lengths.Nx;
	int stride = 1;
	int dist =FFT_lengths.Nx*FFT_lengths.Ny;
	cuFFT_error = cufftPlanMany(&plan, rank, n, nembed, stride, dist, nembed, stride, dist, CUFFT_Z2D, nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecZ2D(plan, (cufftDoubleComplex *) FFT_mem.d_input, FFT_mem.d_output);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}


// ***********************************************************************************
// ***********************************************************************************
// ***********************************************************************************


int cuFFT_3D_C2C_float(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<float> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data(FFT_size.input_nElements*2, FFT_conf.FFT_host_to_device);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	int rank = 3;
	int n[3]; n[0]=FFT_lengths.Nz; n[1]=FFT_lengths.Ny; n[2]=FFT_lengths.Nx;
	int nembed[3]; nembed[0]=FFT_lengths.Nz; nembed[1]=FFT_lengths.Ny; nembed[2]=FFT_lengths.Nx;
	int stride = 1;
	int dist =FFT_lengths.Nx*FFT_lengths.Ny*FFT_lengths.Nz;
	cuFFT_error = cufftPlanMany(&plan, rank, n, nembed, stride, dist, nembed, stride, dist, CUFFT_C2C, nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecC2C(plan, (cufftComplex *) FFT_mem.d_input, (cufftComplex *) FFT_mem.d_output, CUFFT_FORWARD);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_3D_R2C_float(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<float> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data(FFT_size.input_nElements, FFT_conf.FFT_host_to_device);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	int rank = 3;
	int n[3]; n[0]=FFT_lengths.Nz; n[1]=FFT_lengths.Ny; n[2]=FFT_lengths.Nx;
	int nembed[3]; nembed[0]=FFT_lengths.Nz; nembed[1]=FFT_lengths.Ny; nembed[2]=FFT_lengths.Nx;
	int stride = 1;
	int dist =FFT_lengths.Nx*FFT_lengths.Ny*FFT_lengths.Nz;
	cuFFT_error = cufftPlanMany(&plan, rank, n, nembed, stride, dist, nembed, stride, dist, CUFFT_R2C, nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecR2C(plan, FFT_mem.d_input, (cufftComplex *) FFT_mem.d_output);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_3D_C2R_float(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<float> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data(FFT_size.input_nElements*2, FFT_conf.FFT_host_to_device);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	int rank = 3;
	int n[3]; n[0]=FFT_lengths.Nz; n[1]=FFT_lengths.Ny; n[2]=FFT_lengths.Nx;
	int nembed[3]; nembed[0]=FFT_lengths.Nz; nembed[1]=FFT_lengths.Ny; nembed[2]=FFT_lengths.Nx;
	int stride = 1;
	int dist =FFT_lengths.Nx*FFT_lengths.Ny*FFT_lengths.Nz;
	cuFFT_error = cufftPlanMany(&plan, rank, n, nembed, stride, dist, nembed, stride, dist, CUFFT_C2R, nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecC2R(plan, (cufftComplex *) FFT_mem.d_input, FFT_mem.d_output);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}


int cuFFT_3D_C2C_double(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<double> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data(FFT_size.input_nElements*2, FFT_conf.FFT_host_to_device);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	int rank = 3;
	int n[3]; n[0]=FFT_lengths.Nz; n[1]=FFT_lengths.Ny; n[2]=FFT_lengths.Nx;
	int nembed[3]; nembed[0]=FFT_lengths.Nz; nembed[1]=FFT_lengths.Ny; nembed[2]=FFT_lengths.Nx;
	int stride = 1;
	int dist =FFT_lengths.Nx*FFT_lengths.Ny*FFT_lengths.Nz;
	cuFFT_error = cufftPlanMany(&plan, rank, n, nembed, stride, dist, nembed, stride, dist, CUFFT_Z2Z, nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecZ2Z(plan, (cufftDoubleComplex *) FFT_mem.d_input, (cufftDoubleComplex *) FFT_mem.d_output, CUFFT_FORWARD);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_3D_R2C_double(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<double> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data(FFT_size.input_nElements, FFT_conf.FFT_host_to_device);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	int rank = 3;
	int n[3]; n[0]=FFT_lengths.Nz; n[1]=FFT_lengths.Ny; n[2]=FFT_lengths.Nx;
	int nembed[3]; nembed[0]=FFT_lengths.Nz; nembed[1]=FFT_lengths.Ny; nembed[2]=FFT_lengths.Nx;
	int stride = 1;
	int dist =FFT_lengths.Nx*FFT_lengths.Ny*FFT_lengths.Nz;
	cuFFT_error = cufftPlanMany(&plan, rank, n, nembed, stride, dist, nembed, stride, dist, CUFFT_D2Z, nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecD2Z(plan, FFT_mem.d_input, (cufftDoubleComplex *) FFT_mem.d_output);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}

int cuFFT_3D_C2R_double(FFT_Lengths FFT_lengths, size_t nFFTs, int nRuns, int device, FFT_Configuration FFT_conf, FFT_Sizes FFT_size, double *execution_time, double *standard_deviation, double *transfer_time, float signal_amplitude, float noise_stdev){
	int error;
	//---------> Initial nVidia stuff
	error = Initiate_device(device);
	if(error!=0) return(1);
	
	error = Check_free_memory(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size);
	if(error!=0) return(1);

	//---------> Measurements
	double FFT_execution_time = 0, FFT_transfer_time = 0, dtemp = 0;
	GpuTimer timer;
	
	//---------> Memory
	FFT_Memory<double> FFT_mem;
	FFT_mem.Allocate(FFT_size.total_input_FFT_size, FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace);
	FFT_mem.Generate_data(FFT_size.input_nElements*2, FFT_conf.FFT_host_to_device);
	FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &FFT_transfer_time);
	
	
	//------------------------------------------------------------
	//---------> cuFFT
	cufftHandle plan;
	cufftResult cuFFT_error;
	int rank = 3;
	int n[3]; n[0]=FFT_lengths.Nz; n[1]=FFT_lengths.Ny; n[2]=FFT_lengths.Nx;
	int nembed[3]; nembed[0]=FFT_lengths.Nz; nembed[1]=FFT_lengths.Ny; nembed[2]=FFT_lengths.Nx;
	int stride = 1;
	int dist =FFT_lengths.Nx*FFT_lengths.Ny*FFT_lengths.Nz;
	cuFFT_error = cufftPlanMany(&plan, rank, n, nembed, stride, dist, nembed, stride, dist, CUFFT_Z2D, nFFTs);
	std::vector<double> times; 
	if (CUFFT_SUCCESS == cuFFT_error) {
		for(int f=0; f<nRuns; f++){
			if(HOST_TO_DEVICE==1) FFT_mem.Transfer_input(FFT_size.total_input_FFT_size, FFT_conf.FFT_host_to_device, &dtemp);
			timer.Start();
			//--------------------------------> cuFFT execution
			cufftExecZ2D(plan, (cufftDoubleComplex *) FFT_mem.d_input, FFT_mem.d_output);
			timer.Stop();
			times.push_back(timer.Elapsed());
			FFT_execution_time += timer.Elapsed();
		}
		FFT_execution_time = FFT_execution_time/((double) nRuns);
	}
	else printf("CUFFT error: Plan creation failed");
	
	cufftDestroy(plan);
	//------------------------------------------------------------<
	
	FFT_mem.Transfer_output(FFT_size.total_output_FFT_size, FFT_conf.FFT_host_to_device, FFT_conf.FFT_inplace, &FFT_transfer_time);
	#ifdef EXPORT
		FFT_mem.Export_fft_result(FFT_conf, FFT_lengths);
		FFT_mem.Export_fft_input(FFT_conf, FFT_lengths);
	#endif
	*execution_time = FFT_execution_time; *transfer_time = FFT_transfer_time; *standard_deviation = stdev(&times, FFT_execution_time);
	
	//---------> error check -----
	checkCudaErrors(cudaGetLastError());
	return(0);
}