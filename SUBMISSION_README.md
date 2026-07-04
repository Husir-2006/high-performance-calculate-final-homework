# 高性能计算课程设计复现说明

## 1. 项目题目

光线追踪渲染器的串行、OpenMP 与 CUDA 并行优化。

小组信息：第 8 组，24281098 胡哲祺，24281100 李建宇。

## 2. 目录说明

- `v1_serial/`：原始串行版本，作为基准程序。
- `v2_openmp/`：OpenMP 多线程优化版本。
- `v3_cuda/`：CUDA GPU 优化版本。
- `scripts/`：编译、测试、绘图和超算提交脚本。
- `results/`：已有渲染结果、运行截图和报告素材。
- `README.md`：项目概览与快速运行方法。
- `EXPERIMENT_GUIDE.md`：详细实验步骤和数据记录方法。
- `高性能计算光线追踪渲染器实验报告.docx`：实验报告。
- `高性能计算光线追踪渲染器答辩PPT.pdf`：答辩用 PDF。
- `submit.sh`：当前超算 Slurm GPU 分区使用的提交脚本。

## 3. 测试环境

本项目在本地 macOS 环境完成代码整理与文档生成，在超算平台完成 CPU/OpenMP/CUDA 三版本测试，并通过 Slurm 提交 CUDA 版本到 GPU 队列。

超算平台已验证可用的 CUDA 模块：

```bash
module load intel/cuda/12.1
```

登录节点直接运行 CUDA 程序可能出现驱动版本不足问题，应通过 `sbatch` 提交到 GPU 计算节点运行。

## 4. 编译方法

```bash
g++ -O2 -std=c++17 v1_serial/main.cpp -o v1_serial/v1_serial
g++ -O2 -std=c++17 -fopenmp v2_openmp/main.cpp -o v2_openmp/v2_openmp
module load intel/cuda/12.1
nvcc -O3 -arch=sm_80 v3_cuda/main.cu -o v3_cuda/v3_cuda
```

## 5. 运行方法

串行版本：

```bash
./v1_serial/v1_serial --width 400 --height 300 --samples 64 --scene racing
```

OpenMP 版本：

```bash
OMP_NUM_THREADS=8 ./v2_openmp/v2_openmp --width 400 --height 300 --samples 64 --scene racing
```

CUDA 版本建议提交到 GPU 队列：

```bash
chmod +x submit.sh
sbatch submit.sh ./v3_cuda/v3_cuda
squeue -u $USER
```

## 6. 已有实测结果

在 400 x 300 分辨率、64 samples 参数下：

| 版本 | 并行方式 | 运行时间 |
|---|---:|---:|
| V1 Serial | 单线程 | 39.1013 s |
| V2 OpenMP | 8 线程 | 9.72383 s |
| V3 CUDA | GPU | 0.126103 s |

OpenMP 相对串行加速比约为 4.02 倍，并行效率约为 50.3%。CUDA 相对串行加速比约为 310.07 倍，输出文件为 `results/v3_output.ppm`，运行时间记录在 `job.out` 中。
