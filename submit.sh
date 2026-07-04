#!/bin/bash
#SBATCH -p gpu_4090
#SBATCH -n 1
#SBATCH -G 1
#SBATCH -o job.out

$1

