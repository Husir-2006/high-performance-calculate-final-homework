# 高性能计算大作业实验报告

## 光线追踪渲染器的串行、OpenMP 与 CUDA 并行加速

### 摘要

本课程设计实现了一个基于光线追踪的渲染器，并在原始串行版本基础上完成 OpenMP 多线程优化和 CUDA GPU 优化。实验任务以像素级光线追踪为核心，每个像素需要进行多次采样、求交、材质散射和颜色累积，计算密度高且像素之间相互独立，适合使用高性能计算技术进行加速。

目前已在超算平台完成串行版本和 OpenMP 版本实测。测试参数为 400 x 300 分辨率、64 samples，串行版本运行时间为 39.1013 s，OpenMP 8 线程版本运行时间为 9.72383 s，加速比约为 4.02x。CUDA 版本已在 `intel/cuda/12.1` 模块下完成编译，并通过 Slurm 提交到 `gpu_4090` 分区测试。

### 1. 研究背景与意义

光线追踪通过模拟光线与场景物体的相交、反射、折射和散射过程生成图像，能够获得较真实的阴影、反射、透明材质和景深效果。随着现代游戏和影视渲染对画面质量要求提高，光线追踪已经成为图形渲染中的重要技术。

光线追踪的主要瓶颈是计算量大。分辨率、采样数和递归深度增加时，每帧需要处理的光线数量会快速上升。因此，本项目选择光线追踪作为优化对象，用于体现 CPU 多线程和 GPU 并行计算在图形渲染任务中的应用价值。

### 2. 研究内容

- 实现 C++17 串行光线追踪渲染器，作为性能基准。
- 基于 OpenMP 对像素循环进行并行化，测试 CPU 多核加速效果。
- 设计 CUDA 版本，将每个像素映射到一个 GPU 线程。
- 生成 PPM 渲染结果，并将关键结果转为 PNG/JPG 插入报告。
- 在超算平台记录编译、运行、排队和结果检查过程。

### 3. 技术路线

```text
V1 串行版 C++ 光线追踪
        ↓  OpenMP parallel for 并行像素循环
V2 OpenMP CPU 多线程版本
        ↓  CUDA thread 映射像素计算
V3 CUDA GPU 大规模并行版本
```

三种版本共享相同的基本渲染流程，主要区别在于像素任务的调度方式。串行版本按顺序计算，OpenMP 版本将像素行分配给多个 CPU 线程，CUDA 版本将像素映射到 GPU 线程并在显存中保存场景数据。

### 4. 实现方法

串行版本逐像素计算颜色，每个像素进行多次随机采样，用于抗锯齿和降低噪声。OpenMP 版本使用 `#pragma omp parallel for schedule(dynamic, 1)` 并行图像行循环，并通过 framebuffer 避免多线程同时写文件。CUDA 版本使用二维 grid/block 组织线程，每个线程负责一个像素，递归光线追踪改为迭代形式以降低 GPU 栈压力。

CUDA 版本中球体和材质数据通过 `cudaMalloc` 分配到显存，再作为 kernel 参数传入，避免带构造函数结构体放入 `__constant__` 变量时产生动态初始化错误。

### 5. 运行结果

超算实测结果如下：

| 版本 | 并行方式 | 运行时间 / s | 相对串行加速比 |
|---|---:|---:|---:|
| V1 Serial | 1 线程 | 39.1013 | 1.00 |
| V2 OpenMP | 8 线程 | 9.72383 | 4.02 |
| V3 CUDA | GPU | 排队/待补充最终时间 | 待补充 |

CUDA 程序曾在登录节点直接运行时出现 `CUDA driver version is insufficient for CUDA runtime version`。该问题不是代码编译错误，而是登录节点通常不提供匹配的 GPU 运行环境。通过 Slurm 提交到 GPU 计算节点后，驱动环境问题消失。

### 6. 性能分析

OpenMP 8 线程版本将运行时间从 39.1013 s 降低到 9.72383 s：

```text
Speedup = 39.1013 / 9.72383 ≈ 4.02
Efficiency = 4.02 / 8 ≈ 50.3%
```

加速比未达到理想 8x 的主要原因包括：文件输出和部分初始化仍为串行过程；不同像素的反射、折射次数不同导致负载不均；动态调度和随机数生成带来额外开销；线程数增加后内存带宽和缓存访问成为限制因素。

### 7. 复现方法

```bash
g++ -O2 -std=c++17 v1_serial/main.cpp -o v1_serial/v1_serial
g++ -O2 -std=c++17 -fopenmp v2_openmp/main.cpp -o v2_openmp/v2_openmp

module load intel/cuda/12.1
nvcc -O3 -arch=sm_80 v3_cuda/main.cu -o v3_cuda/v3_cuda

./v1_serial/v1_serial --width 400 --height 300 --samples 64 --scene racing
OMP_NUM_THREADS=8 ./v2_openmp/v2_openmp --width 400 --height 300 --samples 64 --scene racing
sbatch scripts/submit_gpu_slurm.sh
```

### 8. 结论

本项目完成了从串行程序到 CPU 多线程再到 GPU 并行的递进式优化。实验表明，光线追踪具有明显的像素级并行特征，OpenMP 已经能够在超算 CPU 节点上获得明显加速。CUDA 版本完成编译和作业提交流程，为后续补充 GPU 最终运行时间和更复杂场景渲染奠定了基础。
