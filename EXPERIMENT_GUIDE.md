# 实验指导步骤

## 1. 实验目标

实现并测试光线追踪渲染器的串行、OpenMP、CUDA 三个版本，比较不同并行方式的运行时间、加速比和扩展效率。

## 2. 实验环境准备

在超算登录节点进入项目目录：

```bash
cd /path/to/HighperformanceExp
```

加载编译环境，具体模块名以学校平台为准：

```bash
module load gcc/11.2.0
module load intel/cuda/12.0
```

确认工具可用：

```bash
g++ --version
nvcc --version
python3 --version
```

## 3. 小规模正确性测试

先用较小参数快速确认三个版本都能输出图片：

```bash
g++ -O2 -std=c++17 v1_serial/main.cpp -o v1_serial/v1_serial
g++ -O2 -std=c++17 -fopenmp v2_openmp/main.cpp -o v2_openmp/v2_openmp
nvcc -O3 -arch=sm_80 v3_cuda/main.cu -o v3_cuda/v3_cuda
```

```bash
cd v1_serial
./v1_serial --width 200 --height 150 --samples 8 --scene racing
cp output.ppm ../results/v1_test.ppm

cd ../v2_openmp
OMP_NUM_THREADS=4 ./v2_openmp --width 200 --height 150 --samples 8 --scene racing
cp output.ppm ../results/v2_test.ppm

cd ..
./v3_cuda/v3_cuda --width 200 --height 150 --samples 8 --scene racing --output results/v3_test.ppm
```

检查三张图是否都是同一场景。由于随机采样不同，像素不要求完全一致，但主体球、地面、天空方向应一致。

## 4. 正式性能测试

推荐参数：

```bash
WIDTH=1200 HEIGHT=800 SAMPLES=256 SCENE=blackhole CUDA_ARCH=sm_80 bash scripts/run_benchmark.sh
```

如果队列时间紧，可以先用：

```bash
WIDTH=800 HEIGHT=600 SAMPLES=64 bash scripts/run_benchmark.sh
```

脚本会自动测试：

- V1 串行版本
- V2 OpenMP 的 `1, 2, 4, 8, 16, 32` 线程
- V3 CUDA 版本，如果当前环境存在 `nvcc`

结果写入：

```text
results/benchmark_results.csv
```

## 5. 绘制加速比图

```bash
python3 scripts/plot_speedup.py
```

输出：

```text
results/speedup.png
```

如果缺少 matplotlib，在超算上可尝试：

```bash
module load python
python3 -m pip install --user matplotlib
```

## 6. 使用作业脚本

CPU 队列：

```bash
qsub scripts/submit_cpu.pbs
```

GPU 队列：

```bash
qsub scripts/submit_gpu.pbs
```

提交后查看作业：

```bash
qstat
```

作业完成后检查 `results/` 目录中的 CSV、PPM 和 PNG 文件。

## 7. 报告建议记录的数据

报告中至少放以下数据：

- V1 串行运行时间 `T_serial`
- V2 在 1、2、4、8、16、32 线程下的运行时间
- V3 CUDA 运行时间
- OpenMP 加速比 `S(p)=T_serial/T_parallel(p)`
- OpenMP 并行效率 `E(p)=S(p)/p`
- CUDA 相对 V1 的加速比

可以根据 `benchmark_results.csv` 补充一列效率：

```text
efficiency = speedup / threads
```

CUDA 行的 `threads` 字段为 `gpu`，不计算 OpenMP 式效率。

## 8. 报告分析要点

OpenMP 部分重点说明：

- 每个像素独立，适合并行。
- 使用 `schedule(dynamic, 1)` 缓解不同像素追踪深度不同导致的负载不均。
- 线程数继续增加时，加速比可能受串行初始化、文件 IO、内存带宽和调度开销限制。

CUDA 部分重点说明：

- 每个 CUDA thread 负责一个像素。
- 递归 `ray_color` 改为迭代，避免 GPU 栈深度压力。
- 球体和材质放在 constant memory，适合所有线程只读访问。
- 反射、折射、漫反射分支会造成 warp divergence。

## 9. 常见问题

`omp.h` 找不到：

说明当前编译器没有 OpenMP 支持。超算上加载 GCC 后再编译，或设置 `CXX=g++`。

`nvcc` 找不到：

说明当前不是 CUDA 环境或没有加载 CUDA 模块。先执行 `module load intel/cuda/12.0`。

CUDA 架构不匹配：

根据 GPU 修改 `CUDA_ARCH`。常见值：

- A100：`sm_80`
- V100：`sm_70`
- RTX 30 系：`sm_86`
- RTX 40 系：`sm_89`

运行时间波动较大：

固定使用独占节点，避免和其他任务共享资源；正式数据建议每组运行 3 次取平均。
