#!/bin/bash
#SBATCH -J ray_cuda
#SBATCH -p gpu_4090
#SBATCH -N 1
#SBATCH --gres=gpu:1
#SBATCH -t 00:20:00
#SBATCH -o slurm-%j.out

set -e

cd "${SLURM_SUBMIT_DIR:-$PWD}"
module load intel/cuda/12.1

mkdir -p results
nvcc -O3 -arch=sm_80 v3_cuda/main.cu -o v3_cuda/v3_cuda
./v3_cuda/v3_cuda --width 1200 --height 800 --samples 256 --scene racing --output results/v3_output.ppm
