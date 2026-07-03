# 高性能计算大作业：光线追踪渲染器并行加速

> 本文件用于 Claude Code 上下文初始化。进入项目后执行：
> ```
> cat PLANNING.md
> ```
> 然后告诉 Claude Code："请根据 PLANNING.md 开始工作，先完成 V1 串行版"

---

## 当前实现进度（2026-07-01 更新）

- V1 串行版：已完成，源码在 `v1_serial/`，可用 `g++ -O2 -std=c++17` 编译，输出 `output.ppm`。
- V2 OpenMP 版：已完成，源码在 `v2_openmp/`，使用 `#pragma omp parallel for schedule(dynamic, 1)` 并支持 `OMP_NUM_THREADS`。
- V3 CUDA 版：已补齐，源码在 `v3_cuda/`，包含 `main.cu`、`vec3.cuh`、`ray.cuh`、`hittable.cuh`、`sphere.cuh`、`material.cuh`、`camera.cuh`。
- 自动化脚本：已补齐，`scripts/run_benchmark.sh` 负责编译运行并生成 CSV，`scripts/plot_speedup.py` 负责绘制加速比图。
- 超算脚本：已补齐，`scripts/submit_cpu.pbs` 和 `scripts/submit_gpu.pbs` 可作为 PBS 队列模板。
- 实验说明：已补齐，见 `README.md` 和 `EXPERIMENT_GUIDE.md`。

本地验证情况：

- V1 已在当前机器编译通过。
- Python 绘图脚本已通过语法检查。
- 当前机器的 `g++` 实际为 Apple clang，不支持 `-fopenmp`，V2 需在加载 GCC/OpenMP 的超算环境验证。
- 当前机器未安装 `nvcc`，V3 需在 CUDA 节点验证。

---

## 项目背景

课程：高性能计算导论（大二）
平台：远程超算（多核 CPU 节点 + GPU 节点）
人数：2-3 人小组
目标：用 HPC 技术优化光线追踪渲染器，对比串行 / OpenMP / CUDA 三版本性能

---

## 技术路线总览

```
V1 串行版 (C++ 单线程)
    ↓  加 #pragma omp parallel for
V2 OpenMP 版 (CPU 多核并行)
    ↓  改写为 CUDA kernel
V3 CUDA 版 (GPU 大规模并行)
```

三个版本渲染结果必须一致（像素级别允许浮点误差），以此验证正确性。

---

## 目录结构

```
ray_tracing_hpc/
├── PLANNING.md          ← 本文件
├── README.md            ← 编译与运行说明（需生成）
├── v1_serial/
│   ├── main.cpp
│   ├── vec3.h
│   ├── ray.h
│   ├── hittable.h
│   ├── sphere.h
│   ├── material.h
│   └── camera.h
├── v2_openmp/
│   ├── main.cpp         ← 在 v1 基础上加 OpenMP pragma
│   └── (其余头文件与 v1 共享或复制)
├── v3_cuda/
│   ├── main.cu
│   ├── vec3.cuh
│   ├── ray.cuh
│   ├── hittable.cuh
│   ├── sphere.cuh
│   ├── material.cuh
│   └── camera.cuh
├── scripts/
│   ├── run_benchmark.sh ← 自动采集运行时间
│   ├── submit_cpu.pbs   ← 超算 CPU 节点作业脚本
│   ├── submit_gpu.pbs   ← 超算 GPU 节点作业脚本
│   └── plot_speedup.py  ← 绘制加速比图表
└── results/
    ├── v1_output.ppm
    ├── v2_output.ppm
    ├── v3_output.ppm
    └── benchmark_results.csv
```

---

## V1 串行版实现要点

### 核心数据结构

```cpp
// vec3.h —— 三维向量，所有几何运算的基础
struct Vec3 {
    float x, y, z;
    Vec3 operator+(const Vec3& v) const;
    Vec3 operator*(float t) const;
    float dot(const Vec3& v) const;
    Vec3 cross(const Vec3& v) const;
    Vec3 normalize() const;
    float length() const;
};

// ray.h —— 光线 = 起点 + 方向
struct Ray {
    Vec3 origin, direction;
    Vec3 at(float t) const { return origin + direction * t; }
};

// hittable.h —— 可求交物体的抽象基类
struct HitRecord { Vec3 point, normal; float t; int mat_id; };
struct Hittable {
    virtual bool hit(const Ray& r, float t_min, float t_max, HitRecord& rec) const = 0;
};

// sphere.h —— 球体求交（解析解）
struct Sphere : public Hittable {
    Vec3 center; float radius; int mat_id;
    bool hit(const Ray& r, float t_min, float t_max, HitRecord& rec) const override;
    // 判别式: b²-4ac，解二次方程
};
```

### 渲染主循环（V1）

```cpp
// main.cpp 核心结构
int main() {
    const int WIDTH = 800, HEIGHT = 600, SAMPLES = 64;
    // 初始化场景、相机、像素缓冲区

    for (int j = HEIGHT-1; j >= 0; j--) {
        for (int i = 0; i < WIDTH; i++) {
            Vec3 color(0,0,0);
            for (int s = 0; s < SAMPLES; s++) {  // 抗锯齿采样
                float u = (i + random_float()) / WIDTH;
                float v = (j + random_float()) / HEIGHT;
                Ray r = camera.get_ray(u, v);
                color += ray_color(r, world, MAX_DEPTH);
            }
            color /= SAMPLES;
            write_pixel(out, color);  // 写入 PPM
        }
    }
}

// 递归追踪（最大深度 MAX_DEPTH=50）
Vec3 ray_color(const Ray& r, const Hittable& world, int depth) {
    if (depth <= 0) return Vec3(0,0,0);
    HitRecord rec;
    if (world.hit(r, 0.001, INF, rec)) {
        Ray scattered; Vec3 attenuation;
        if (scatter(rec, r, attenuation, scattered))
            return attenuation * ray_color(scattered, world, depth-1);
        return Vec3(0,0,0);
    }
    // 背景色（天空渐变）
    Vec3 unit = r.direction.normalize();
    float t = 0.5f * (unit.y + 1.0f);
    return Vec3(1,1,1)*(1-t) + Vec3(0.5,0.7,1.0)*t;
}
```

### 材质系统（3种）

```
Lambertian (漫反射) — 随机散射，适合哑光球
Metal       (金属)   — 镜面反射 + 模糊参数，适合镜面球
Dielectric  (玻璃)   — Schlick 近似折射，适合透明球
```

### 场景设计（答辩用）

```
场景内容：
- 1 个大地面球（半径100，Lambertian灰色）
- 3 个主球（金属/玻璃/漫反射各一）
- 若干小随机球（随机材质，用于填充背景）
- 点光源（用于产生阴影）

渲染参数：
- 分辨率：1200×800（超算跑）/ 400×300（本地测试）
- 采样数：64（快速）/ 256（答辩图）/ 1024（封面图）
```

---

## V2 OpenMP 版实现要点

在 V1 基础上改动极小，仅需：

```cpp
// 在像素双重循环前加一行 pragma
#pragma omp parallel for schedule(dynamic, 1) reduction(+:pixel_colors[:WIDTH*HEIGHT*3])
for (int j = HEIGHT-1; j >= 0; j--) {
    for (int i = 0; i < WIDTH; i++) {
        // ... 渲染逻辑不变
    }
}
```

**注意事项：**
- 随机数生成器需线程局部：`thread_local std::mt19937 rng(omp_get_thread_num());`
- 用 `schedule(dynamic, 1)` 做动态调度，避免负载不均（边缘行像素计算更快）
- 编译加 `-fopenmp` 标志

**性能实验设计：**
```bash
# 测试线程数：1 2 4 8 16 32
for T in 1 2 4 8 16 32; do
    OMP_NUM_THREADS=$T ./v2_openmp > /dev/null
    echo "Threads=$T Time=$(...)s"
done
```

---

## V3 CUDA 版实现要点

### 关键设计决策

**1. 线程映射**
```
每个 CUDA thread = 一个像素
Block 大小 = 16×16 = 256 threads
Grid 大小 = ceil(WIDTH/16) × ceil(HEIGHT/16)
```

**2. 递归→迭代（必须做）**
CUDA 栈深度有限，光线追踪的递归必须展开：

```cuda
// 递归版（CPU可以，CUDA会爆栈）
Vec3 ray_color_recursive(Ray r, int depth) { ... }

// 迭代版（CUDA正确做法）
__device__ Vec3 ray_color_iterative(Ray r, Hittable* world) {
    Vec3 accumulated_attenuation(1,1,1);
    for (int depth = 0; depth < MAX_DEPTH; depth++) {
        HitRecord rec;
        if (world->hit(r, 0.001f, 1e30f, rec)) {
            Ray scattered; Vec3 attenuation;
            if (scatter_device(rec, r, attenuation, scattered)) {
                accumulated_attenuation *= attenuation;
                r = scattered;
            } else break;
        } else {
            // 背景色
            return accumulated_attenuation * background(r);
        }
    }
    return Vec3(0,0,0);
}
```

**3. 内存布局**
```cuda
// 场景数据放 constant memory（只读，GPU L1缓存）
__constant__ Sphere d_spheres[MAX_SPHERES];
__constant__ int d_num_spheres;

// 渲染结果放 device memory，最后 cudaMemcpy 回 host
float* d_framebuffer;  // WIDTH * HEIGHT * 3 floats
cudaMalloc(&d_framebuffer, WIDTH * HEIGHT * 3 * sizeof(float));
```

**4. CUDA Kernel**
```cuda
__global__ void render_kernel(
    float* framebuffer, int width, int height,
    int samples, Camera cam, curandState* rand_states
) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int j = blockIdx.y * blockDim.y + threadIdx.y;
    if (i >= width || j >= height) return;

    int idx = j * width + i;
    curandState local_rand = rand_states[idx];
    Vec3 color(0,0,0);

    for (int s = 0; s < samples; s++) {
        float u = (i + curand_uniform(&local_rand)) / width;
        float v = (j + curand_uniform(&local_rand)) / height;
        Ray r = cam.get_ray(u, v, &local_rand);
        color += ray_color_iterative(r, ...);
    }

    color /= samples;
    framebuffer[idx*3+0] = color.x;
    framebuffer[idx*3+1] = color.y;
    framebuffer[idx*3+2] = color.z;
}
```

**5. 编译命令**
```bash
nvcc -O3 -arch=sm_80 -o v3_cuda main.cu   # A100
nvcc -O3 -arch=sm_70 -o v3_cuda main.cu   # V100
```

---

## 超算提交脚本模板

### CPU 节点（PBS/Slurm）
```bash
#!/bin/bash
#PBS -N ray_openmp
#PBS -l nodes=1:ppn=32
#PBS -l walltime=00:30:00
#PBS -q normal

cd $PBS_O_WORKDIR
module load gcc/11.2.0

for T in 1 2 4 8 16 32; do
    export OMP_NUM_THREADS=$T
    START=$(date +%s%N)
    ./v2_openmp
    END=$(date +%s%N)
    echo "T=$T time=$(( (END-START)/1000000 ))ms" >> results/cpu_benchmark.txt
done
```

### GPU 节点
```bash
#!/bin/bash
#PBS -N ray_cuda
#PBS -l nodes=1:gpus=1
#PBS -l walltime=00:10:00
#PBS -q gpu

cd $PBS_O_WORKDIR
module load cuda/12.0

./v3_cuda --width 1200 --height 800 --samples 256
```

---

## 性能分析要点（报告必写）

### 1. 加速比（Speedup）
```
S(p) = T_serial / T_parallel(p)
效率 E(p) = S(p) / p
```
预期数据：OpenMP 32核约 20-28x，CUDA 约 30-100x

### 2. Amdahl 定律验证
```
S_max = 1 / (f_serial + (1-f_serial)/p)
估算串行部分比例 f_serial（IO、初始化等）
```

### 3. CUDA 特有分析
- **Warp occupancy**：用 `nvcc --ptxas-options=-v` 查看寄存器使用
- **Warp divergence**：光线反射/折射分支导致 warp 内线程走不同路径
- **内存访问**：framebuffer 写入是否 coalesced
- 工具：`nvprof` 或 `Nsight Compute`

### 4. Roofline 模型（加分项）
对比计算强度（FLOPs/Byte）与硬件峰值，判断瓶颈是计算还是内存带宽

---

## 实验报告章节结构

```
1. 研究背景与意义（1页）
   - 光线追踪在电影/游戏工业的应用（RTX, Pixar）
   - HPC 在图形渲染领域的必要性
   - 本课题意义

2. 研究内容（0.5页）
   - 实现目标：三版本渲染器
   - 对比维度：时间、加速比、渲染质量

3. 技术路线（1页）
   - V1/V2/V3 架构图
   - 核心算法简述（光线求交、着色模型）

4. 实现方法（2页）
   - V1：串行渲染循环，关键数据结构
   - V2：OpenMP 并行策略，线程安全处理
   - V3：CUDA kernel 设计，递归→迭代改造

5. 运行结果截图（1页）
   - 三版本渲染图对比
   - 超算平台运行截图

6. 性能分析（2页）
   - 加速比折线图（OpenMP 线程数）
   - V1/V2/V3 柱状对比图
   - Amdahl 定律分析
   - CUDA warp divergence 分析

7. 结论（0.5页）
```

---

## 给 Claude Code 的任务指令

使用以下格式向 Claude Code 下达任务：

```
# 任务1：生成 V1 串行版
请根据 PLANNING.md 的规格，生成 v1_serial/ 目录下的全部文件：
- vec3.h（包含所有向量运算）
- ray.h
- hittable.h 和 sphere.h
- material.h（Lambertian / Metal / Dielectric）
- camera.h
- main.cpp（包含场景设置和主渲染循环）
要求：能用 g++ -O2 -std=c++17 编译通过，输出 output.ppm

# 任务2：生成 V2 OpenMP 版
基于 v1_serial/main.cpp，生成 v2_openmp/main.cpp
加入 OpenMP 并行，支持 OMP_NUM_THREADS 环境变量控制线程数
输出运行时间到 stderr

# 任务3：生成 V3 CUDA 版
根据 PLANNING.md 的 CUDA 设计方案，生成 v3_cuda/main.cu
包含：iterative ray_color、constant memory 场景、curand 随机数
编译命令：nvcc -O3 -arch=sm_80

# 任务4：生成测试脚本
生成 scripts/run_benchmark.sh 和 scripts/plot_speedup.py
benchmark 脚本测试 V1/V2(1,2,4,8,16,32线程)/V3，结果写 CSV
Python 脚本读 CSV 用 matplotlib 绘制加速比折线图
```

---

## 参考资料

- Peter Shirley《Ray Tracing in One Weekend》（免费在线）：https://raytracing.github.io
- CUDA Programming Guide：https://docs.nvidia.com/cuda/cuda-c-programming-guide/
- OpenMP 规范：https://www.openmp.org/specifications/

---

*由 Claude claude.ai 根据课程要求自动生成 · 2026-06-16*
