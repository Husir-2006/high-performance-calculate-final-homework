# Ray Tracing HPC

第 8 组：24281098 胡哲祺，24281100 李建宇。

本项目实现一个小型光线追踪渲染器，并对比三种执行方式：

- `v1_serial/`：C++17 串行版本
- `v2_openmp/`：OpenMP 多线程 CPU 版本
- `v3_cuda/`：CUDA GPU 版本

渲染输出为 PPM 图片，性能数据写入 `results/benchmark_results.csv`。

## 本地快速编译

```bash
g++ -O2 -std=c++17 v1_serial/main.cpp -o v1_serial/v1_serial
g++ -O2 -std=c++17 -fopenmp v2_openmp/main.cpp -o v2_openmp/v2_openmp
nvcc -O3 -arch=sm_80 v3_cuda/main.cu -o v3_cuda/v3_cuda
```

在当前超算平台上 CUDA 模块名可能是：

```bash
module load intel/cuda/12.1
```

如果本地没有 CUDA 或 OpenMP 环境，可以只编译能支持的版本；完整实验建议在超算节点上完成。

## 单独运行

```bash
cd v1_serial
./v1_serial --width 400 --height 300 --samples 64
./v1_serial --width 400 --height 300 --samples 64 --scene racing

cd ../v2_openmp
OMP_NUM_THREADS=8 ./v2_openmp --width 400 --height 300 --samples 64

cd ..
./v3_cuda/v3_cuda --width 400 --height 300 --samples 64 --output results/v3_output.ppm
```

可选场景：

- `classic`：默认小球光追测试场景
- `blackhole`：原创黑洞/吸积盘科幻场景
- `city_drive`：原创秋日城市追车场景
- `snow_gt`：原创雪地赛道超跑场景
- `racing`：简化赛车展示/赛道氛围场景
- `neon`：夜间霓虹反射场景，适合展示金属和玻璃材质

## 自动 benchmark

```bash
bash scripts/run_benchmark.sh
python3 scripts/plot_speedup.py
```

可用环境变量调整规模：

```bash
WIDTH=1200 HEIGHT=800 SAMPLES=256 SCENE=blackhole CUDA_ARCH=sm_80 bash scripts/run_benchmark.sh
```

一键生成三张展示图：

```bash
WIDTH=1920 HEIGHT=1080 SAMPLES=512 CUDA_ARCH=sm_80 bash scripts/render_showcases.sh
```

输出文件：

- `results/v1_output.ppm`
- `results/v2_output.ppm`
- `results/v3_output.ppm`
- `results/benchmark_results.csv`
- `results/speedup.png`

## 超算提交

CPU/OpenMP：

```bash
qsub scripts/submit_cpu.pbs
```

GPU/CUDA：

```bash
qsub scripts/submit_gpu.pbs
```

如果学校平台使用 Slurm，可使用当前平台脚本：

```bash
chmod +x submit.sh
sbatch submit.sh ./v3_cuda/v3_cuda
```

最终实测参数为 400 x 300、64 samples：

| 版本 | 运行时间 | 相对串行加速比 |
|---|---:|---:|
| V1 Serial | 39.1013 s | 1.00 |
| V2 OpenMP 8 线程 | 9.72383 s | 4.02 |
| V3 CUDA GPU | 0.126103 s | 310.07 |
