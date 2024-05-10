#include <stdio.h>
#include <stdint.h>
#include "../include/utils.cuh"
#include <string.h>
#include <stdlib.h>
#include <inttypes.h>

__const uint64_t limit = 1e8; //MAX NONCE
__device__ int global_flag = 0; //Flag to mark if a thread has found the nonce

//function to search for all nonces from 1 through MAX_NONCE (inclusive) using CUDA Threads
__global__ void findNonce(
    BYTE *block_content, // the content of the block
    BYTE *block_hash, // the hash for the block to be returned
    BYTE *DIFFICULTY, // difficulty
    uint64_t *result_nonce //result nonce to be returned
) {
	//Compute the current length of the block content
    uint64_t current_length = d_strlen((char*)block_content);
	//Compute the nonce corresponding to this thread
    uint64_t nonce = blockIdx.x * blockDim.x + threadIdx.x + 1;
	//Temporary variables to eliminate concurrency issues
    char nonce_string[NONCE_SIZE]; // to store the nonce as a string
	BYTE temp_block_hash[SHA256_HASH_SIZE]; 
	BYTE temp_block_content[BLOCK_SIZE]; 

	//Check if the nonce has been found by another thread
	if (global_flag != 0) {
		return;
	}

	//Copy the block content to the temporary variable
	d_strcpy((char*)temp_block_content, (const char*)block_content);

	//Check if the nonce is within the limit
    if (nonce <= limit) {
		//Convert the nonce to a string
        intToString(nonce, nonce_string);
		//Append the nonce to the block content
        d_strcpy((char*)temp_block_content + current_length, nonce_string);
		//Compute the hash
        apply_sha256(temp_block_content, d_strlen((const char*)temp_block_content) , temp_block_hash, 1); 

		//Check if the hash is less than the difficulty and no other thread has found the nonce
        if (compare_hashes(temp_block_hash, DIFFICULTY) <= 0 && global_flag == 0) {
			//Update the result nonce and block hash
			*result_nonce = nonce;
			d_strcpy((char*)block_hash, (const char*)temp_block_hash);
			//Set the flag to 1
			atomicAdd(&global_flag, 1);
			return;
        }

    }

}




int main(int argc, char **argv) {
	BYTE hashed_tx1[SHA256_HASH_SIZE], hashed_tx2[SHA256_HASH_SIZE], hashed_tx3[SHA256_HASH_SIZE], hashed_tx4[SHA256_HASH_SIZE],
			tx12[SHA256_HASH_SIZE * 2], tx34[SHA256_HASH_SIZE * 2], hashed_tx12[SHA256_HASH_SIZE], hashed_tx34[SHA256_HASH_SIZE],
			tx1234[SHA256_HASH_SIZE * 2], top_hash[SHA256_HASH_SIZE], block_content[BLOCK_SIZE];
	BYTE block_hash[SHA256_HASH_SIZE] = "0000000000000000000000000000000000000000000000000000000000000000"; 
	uint64_t nonce = 0; // The nonce to be found

	// Top hash
	apply_sha256(tx1, strlen((const char*)tx1), hashed_tx1, 1);
	apply_sha256(tx2, strlen((const char*)tx2), hashed_tx2, 1);
	apply_sha256(tx3, strlen((const char*)tx3), hashed_tx3, 1);
	apply_sha256(tx4, strlen((const char*)tx4), hashed_tx4, 1);
	strcpy((char *)tx12, (const char *)hashed_tx1);
	strcat((char *)tx12, (const char *)hashed_tx2);
	apply_sha256(tx12, strlen((const char*)tx12), hashed_tx12, 1);
	strcpy((char *)tx34, (const char *)hashed_tx3);
	strcat((char *)tx34, (const char *)hashed_tx4);
	apply_sha256(tx34, strlen((const char*)tx34), hashed_tx34, 1);
	strcpy((char *)tx1234, (const char *)hashed_tx12);
	strcat((char *)tx1234, (const char *)hashed_tx34);
	apply_sha256(tx1234, strlen((const char*)tx34), top_hash, 1);

	// prev_block_hash + top_hash
	strcpy((char*)block_content, (const char*)prev_block_hash);
	strcat((char*)block_content, (const char*)top_hash);

	cudaEvent_t start, stop;
	startTiming(&start, &stop);

	//Commpute the number of blocks
	const size_t block_size = 256; 
    size_t blocks_no = MAX_NONCE / block_size;
 
	//add an extra block if the division is not exact
    if ((int)MAX_NONCE % block_size != 0) 
    	++blocks_no;

	//device variables
    BYTE *device_block_content = 0;
    BYTE *device_block_hash = 0;
    BYTE *DIFF = 0;
	uint64_t *result_nonce = 0;

	//Allocate memory for the device variables
	cudaMalloc(&result_nonce, sizeof(uint64_t));
    cudaMalloc(&device_block_hash, SHA256_HASH_SIZE);
    cudaMalloc(&device_block_content, BLOCK_SIZE);
	cudaMalloc(&DIFF, SHA256_HASH_SIZE);
	//Copy the data from the host to the device
	cudaMemcpy(device_block_content, block_content, BLOCK_SIZE, cudaMemcpyHostToDevice);
	cudaMemcpy(device_block_hash, block_hash, SHA256_HASH_SIZE, cudaMemcpyHostToDevice);
	cudaMemcpy(DIFF, DIFFICULTY, SHA256_HASH_SIZE, cudaMemcpyHostToDevice);

    //Check if the memory was allocated successfully
    if (device_block_content == 0 || device_block_hash == 0  || DIFF == 0) {
		printf("[DEVICE] Couldn't allocate memory\n");
   		return 1;
  	}

	//Call the kernel function
	findNonce<<<blocks_no, block_size>>>(device_block_content, device_block_hash, DIFF, result_nonce);
	cudaDeviceSynchronize();

	//Copy the results from the device to the host
	cudaMemcpy(&nonce, result_nonce, sizeof(uint64_t), cudaMemcpyDeviceToHost);
	cudaMemcpy(block_hash, device_block_hash, SHA256_HASH_SIZE, cudaMemcpyDeviceToHost);

	//Free the memory
	cudaFree(device_block_content);
	cudaFree(device_block_hash);
	cudaFree(DIFF);
	cudaFree(result_nonce);

	//Print the result
	float seconds = stopTiming(&start, &stop);
	printResult(block_hash, nonce, seconds);

	return 0;
}
