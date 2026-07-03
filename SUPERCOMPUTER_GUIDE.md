# 超算上传与依赖配置指南

本文档用于把本项目从本机上传到超算平台，并完成编译、运行、性能测试和展示材料准备。

## 1. 本机网络准备

如果学校要求通过 iNode 或校园 VPN 访问超算：

1. 打开 iNode 客户端。
2. 登录校园网/VPN。
3. 确认能访问超算登录节点。

可以在终端测试：

```bash
ssh 用户名@超算登录节点地址
```

如果无法连接，优先检查：

- iNode 是否已经连接成功。
- 是否在校园网或 VPN 网络内。
- 超算账号是否开通。
- 登录节点地址、端口、用户名是否正确。

## 2. 本机打包项目

进入项目目录：

```bash
cd /Users/canghe/Grade2Spring/HighperformanceExp
```

推荐重新打包源码和脚本，不把旧结果、可执行文件、系统缓存打进去：

```bash
zip -r ray_tracing_hpc.zip \
  PLANNING.md README.md EXPERIMENT_GUIDE.md SUPERCOMPUTER_GUIDE.md \
  v1_serial v2_openmp v3_cuda scripts \
  -x "*.DS_Store" "*/output.ppm" "*/v1_serial" "*/v2_openmp" "*/v3_cuda" "results/*"
```

如果只想快速上传当前已有压缩包，也可以直接用根目录下的 `1.zip`，但建议确认里面包含最新的 `v3_cuda/`、`scripts/` 和 Markdown 文档。

## 3. 上传到超算

使用 `scp` 上传：

```bash
scp ray_tracing_hpc.zip 用户名@超算登录节点地址:~/
```

如果超算使用非 22 端口：

```bash
scp -P 端口号 ray_tracing_hpc.zip 用户名@超算登录节点地址:~/
```

登录超算后解压：

```bash
ssh 用户名@超算登录节点地址
unzip ray_tracing_hpc.zip -d ray_tracing_hpc
cd ray_tracing_hpc
```

## 4. 依赖环境

本项目需要以下依赖：

- C++ 编译器：GCC，建议 GCC 9 或以上。
- OpenMP：通常随 GCC 提供，编译参数为 `-fopenmp`。
- CUDA Toolkit：用于编译和运行 `v3_cuda`，建议 CUDA 11 或以上。
- Python 3：用于绘制图表。
- matplotlib：用于生成 `results/speedup.png`。

在超算上通常通过 module 加载：

```bash
module avail gcc
module avail cuda
module avail python
```

示例：

```bash
module load gcc/11.2.0
module load intel/cuda/12.0
module load python/3.9
```

检查：

```bash
g++ --version
nvcc --version
python3 --version
```

如果 `matplotlib` 不存在：

```bash
python3 -c "import matplotlib"
```

若报错，可以尝试：

```bash
python3 -m pip install --user matplotlib
```

如果超算登录节点禁止联网安装 Python 包，就先只生成 `benchmark_results.csv`，把 CSV 下载回本机画图。

## 5. 编译命令

串行版：

```bash
g++ -O2 -std=c++17 v1_serial/main.cpp -o v1_serial/v1_serial
```

OpenMP 版：

```bash
g++ -O2 -std=c++17 -fopenmp v2_openmp/main.cpp -o v2_openmp/v2_openmp
```

CUDA 版：

```bash
nvcc -O3 -arch=sm_80 v3_cuda/main.cu -o v3_cuda/v3_cuda
```

常见 GPU 架构参数：

- A100：`sm_80`
- V100：`sm_70`
- RTX 3090：`sm_86`
- RTX 4090：`sm_89`

如果不确定 GPU 型号，在 GPU 节点运行：

```bash
nvidia-smi
```

## 6. 快速正确性测试

先用小参数验证能跑通：

```bash
mkdir -p results

cd v1_serial
./v1_serial --width 200 --height 150 --samples 8
cp output.ppm ../results/v1_test.ppm

cd ../v2_openmp
OMP_NUM_THREADS=4 ./v2_openmp --width 200 --height 150 --samples 8
cp output.ppm ../results/v2_test.ppm

cd ..
./v3_cuda/v3_cuda --width 200 --height 150 --samples 8 --output results/v3_test.ppm
```

三张图应为同一场景。由于随机采样不同，像素不需要完全一致，但画面主体应一致。

## 7. 正式性能测试

推荐先跑中等规模：

```bash
WIDTH=800 HEIGHT=600 SAMPLES=64 bash scripts/run_benchmark.sh
python3 scripts/plot_speedup.py
```

答辩/报告推荐规模：

```bash
WIDTH=1200 HEIGHT=800 SAMPLES=256 SCENE=blackhole CUDA_ARCH=sm_80 bash scripts/run_benchmark.sh
python3 scripts/plot_speedup.py
```

结果文件：

- `results/benchmark_results.csv`
- `results/speedup.png`
- `results/v1_output.ppm`
- `results/v2_output.ppm`
- `results/v3_output.ppm`

## 8. 作业提交

CPU/OpenMP 队列：

```bash
qsub scripts/submit_cpu.pbs
```

GPU/CUDA 队列：

```bash
qsub scripts/submit_gpu.pbs
```

查看作业：

```bash
qstat
```

如果平台使用 Slurm，把 PBS 脚本改成类似：

```bash
sbatch job.slurm
```

核心命令仍然是编译、运行 `scripts/run_benchmark.sh`。

## 9. 让效果更突出的做法

为了让大作业看起来更完整、更有说服力，建议额外做下面几件事。

### 9.1 渲染更高质量图片

用更高采样数生成一张展示图：

```bash
./v3_cuda/v3_cuda --width 1920 --height 1080 --samples 512 --scene blackhole --output results/final_1080p.ppm
```

如果时间允许：

```bash
./v3_cuda/v3_cuda --width 1920 --height 1080 --samples 1024 --scene blackhole --output results/final_cover.ppm
```

报告中用高质量 CUDA 图作为封面或结果展示，会比小图更有视觉冲击。

### 9.2 多次运行取平均

正式数据建议每组参数运行 3 次，取平均值，报告里写明：

```text
每组实验重复运行 3 次，取平均运行时间作为最终结果。
```

这样数据更可靠，也更像完整性能实验。

### 9.3 增加 OpenMP 扩展性分析

报告里画两条线：

- 实际 OpenMP speedup。
- 理想线性加速 `y=x`。

解释为什么实际曲线低于理想线：

- 文件 IO 和初始化仍然是串行部分。
- 不同像素追踪深度不同，存在负载不均。
- 线程调度和同步有开销。
- 核数增加后可能受内存带宽限制。

### 9.4 增加 CUDA 分析

编译时查看寄存器使用：

```bash
nvcc -O3 -arch=sm_80 --ptxas-options=-v v3_cuda/main.cu -o v3_cuda/v3_cuda
```

报告里可以写：

- CUDA 每个线程负责一个像素。
- 使用 16x16 block。
- 球体和材质放在 constant memory。
- 递归追踪改成迭代追踪，避免 GPU 栈开销。
- 反射、折射、漫反射分支会造成 warp divergence。

如果平台有 Nsight Compute：

```bash
ncu ./v3_cuda/v3_cuda --width 800 --height 600 --samples 64 --output results/ncu_test.ppm
```

可记录 occupancy、branch efficiency、global memory throughput 等指标。

### 9.5 补充 Amdahl 定律

用 OpenMP 32 线程数据估算串行比例：

```text
S(p) = 1 / (f + (1-f)/p)
```

根据实测 `S(32)` 反推 `f`，说明并行加速的理论上限。

### 9.6 准备答辩展示材料

建议最终结果目录包含：

```text
results/
├── benchmark_results.csv
├── speedup.png
├── v1_output.ppm
├── v2_output.ppm
├── v3_output.ppm
└── final_cover.ppm
```

答辩 PPT 中放：

- 三版本架构图。
- 三张渲染结果对比。
- OpenMP 线程数加速比折线图。
- V1/V2/V3 总体运行时间柱状图。
- CUDA 优化点说明。

## 10. 从超算下载结果

在本机执行：

```bash
scp -r 用户名@超算登录节点地址:~/ray_tracing_hpc/results ./results_from_hpc
```

如果使用非 22 端口：

```bash
scp -P 端口号 -r 用户名@超算登录节点地址:~/ray_tracing_hpc/results ./results_from_hpc
```

下载后可以在本机打开 CSV、PNG 和 PPM。PPM 如果预览不方便，可以用 ImageMagick 转成 PNG：

```bash
magick results_from_hpc/final_cover.ppm results_from_hpc/final_cover.png
```

没有 ImageMagick 时，也可以用在线工具或 Python/Pillow 转换。
