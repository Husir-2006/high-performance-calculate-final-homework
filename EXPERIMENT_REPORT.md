# 高性能计算大作业实验报告

## 光线追踪渲染器的 OpenMP 与 CUDA 并行加速

课程：高性能计算导论  
项目方向：图形渲染 / 光线追踪 / 并行计算  
实现语言：C++17、OpenMP、CUDA  
实验平台：本地开发环境 + 远程超算平台  

---

## 摘要

本实验实现了一个基于光线追踪的简易渲染器，并在此基础上完成串行版本、OpenMP 多线程版本和 CUDA GPU 版本的设计与实现。项目以每个像素的光线追踪计算为核心任务，通过对像素循环进行并行化，比较不同并行方法对渲染性能的提升效果。

在基础小球场景之外，项目还扩展了若干程序化展示场景，包括黑洞吸积盘、城市追车和雪地赛道等，用于增强渲染结果的视觉表现。当前已在超算平台上完成串行版本和 OpenMP 版本的编译运行。由于登录节点暂未提供 `nvcc`，CUDA 版本已完成源码实现，但 GPU 实测数据仍需在可用 CUDA/GPU 节点上补充。

已有测试结果显示，在 `400 x 300` 分辨率、`64` 采样数下，串行版本运行时间为 `38.2367 s`，OpenMP 8 线程版本运行时间为 `9.72958 s`，加速比约为 `3.93x`。

---

## 1. 研究背景与意义

光线追踪是一种经典的图形渲染方法。与传统光栅化渲染相比，光线追踪通过模拟光线在场景中的传播、反射和折射过程，可以生成更真实的阴影、镜面反射、透明材质和景深效果。因此，光线追踪被广泛应用于电影特效、离线渲染、工业可视化以及现代游戏图形技术中。

光线追踪的主要缺点是计算量大。对于每个像素，需要发射一条或多条光线，并递归计算其与场景物体的交点和材质散射结果。当分辨率、采样数和递归深度增加时，计算量会迅速上升。因此，光线追踪天然适合使用高性能计算技术进行加速。

本项目选择光线追踪作为实验对象，原因如下：

- 每个像素的颜色计算相对独立，适合 CPU 多线程和 GPU 大规模并行。
- 渲染任务计算量较大，能够较明显地体现并行加速效果。
- 渲染结果可以直接可视化，便于检查程序正确性。
- 图形渲染与游戏画面、科幻视觉效果关系密切，适合展示高性能计算的实际应用价值。

---

## 2. 实验目标

本实验的主要目标包括：

1. 实现一个可运行的 C++ 光线追踪渲染器。
2. 实现串行版本，作为性能基准。
3. 基于串行版本实现 OpenMP 多线程并行版本。
4. 设计并实现 CUDA GPU 版本。
5. 对比串行、OpenMP 和 CUDA 三种实现的运行时间和加速比。
6. 生成可视化渲染结果，并分析并行计算在图形渲染任务中的效果。

---

## 3. 技术路线

项目整体技术路线如下：

```text
V1 串行版 C++ 光线追踪
        ↓
V2 OpenMP CPU 多线程并行
        ↓
V3 CUDA GPU 大规模并行
```

三个版本采用相同的核心渲染思想：对图像中的每个像素发射光线，根据光线与场景物体的交点、法线和材质计算最终颜色。串行版本按像素顺序计算，OpenMP 版本在 CPU 上并行计算像素行，CUDA 版本将每个像素映射到一个 GPU 线程。

---

## 4. 程序结构

项目目录结构如下：

```text
HighperformanceExp/
├── v1_serial/          串行版本
├── v2_openmp/          OpenMP 版本
├── v3_cuda/            CUDA 版本
├── scripts/            编译、运行和绘图脚本
├── results/            渲染结果和实验数据
├── README.md
├── EXPERIMENT_GUIDE.md
└── GAME_RENDERING_SCENES.md
```

主要源码文件包括：

- `vec3.h / vec3.cuh`：三维向量计算。
- `ray.h / ray.cuh`：光线表示。
- `sphere.h / sphere.cuh`：球体求交。
- `material.h / material.cuh`：漫反射、金属、玻璃材质。
- `camera.h / camera.cuh`：相机模型。
- `main.cpp / main.cu`：场景构建、主渲染循环和文件输出。

---

## 5. 串行版本实现

串行版本位于 `v1_serial/` 目录。程序使用 C++17 实现，主要流程如下：

1. 初始化相机和场景。
2. 遍历图像中的每个像素。
3. 对每个像素进行多次随机采样以抗锯齿。
4. 对每条采样光线递归计算颜色。
5. 对采样颜色取平均并写入 PPM 图像文件。

核心循环形式如下：

```cpp
for (int j = HEIGHT - 1; j >= 0; j--) {
    for (int i = 0; i < WIDTH; i++) {
        Vec3 color(0, 0, 0);
        for (int s = 0; s < SAMPLES; s++) {
            float u = (i + random_float()) / (WIDTH - 1);
            float v = (j + random_float()) / (HEIGHT - 1);
            Ray r = cam.get_ray(u, v);
            color += ray_color(r, world, materials, MAX_DEPTH);
        }
        write_pixel(out, color, SAMPLES);
    }
}
```

串行版本的优点是结构简单，便于验证算法正确性；缺点是只能使用单个 CPU 核心，渲染速度较慢。

---

## 6. OpenMP 并行版本实现

OpenMP 版本位于 `v2_openmp/` 目录。由于每个像素的颜色计算互相独立，因此可以直接对像素循环进行并行化。本项目采用按行并行的方式：

```cpp
#pragma omp parallel for schedule(dynamic, 1)
for (int j = 0; j < HEIGHT; j++) {
    for (int i = 0; i < WIDTH; i++) {
        ...
    }
}
```

OpenMP 版本相比串行版本做了以下处理：

- 使用 `#pragma omp parallel for` 并行计算像素行。
- 使用 `schedule(dynamic, 1)` 动态调度任务，缓解不同像素计算量不均的问题。
- 使用 framebuffer 保存每个像素的颜色，避免多个线程同时写入同一个文件流。
- 随机数使用 `thread_local` 变量，避免不同线程之间产生数据竞争。

由于渲染过程中不同像素可能遇到不同数量的反射、折射和散射过程，计算量并不完全一致。动态调度可以让较早完成任务的线程继续领取新的行，从而提高 CPU 利用率。

---

## 7. CUDA 版本设计

CUDA 版本位于 `v3_cuda/` 目录。其核心思想是将图像中的每个像素映射到一个 CUDA 线程：

```text
一个 CUDA thread = 一个像素
block 大小 = 16 x 16
grid 大小 = ceil(width / 16) x ceil(height / 16)
```

CUDA 版本主要设计如下：

- 使用 `render_kernel` 并行渲染所有像素。
- 使用 `curand` 为每个像素维护随机数状态。
- 将递归形式的 `ray_color` 改写为迭代形式，避免 GPU 栈深度过大。
- 将球体和材质数据放入 constant memory，适合所有线程只读访问。
- 渲染结果写入 device framebuffer，最后拷贝回 CPU 并输出 PPM。

CUDA 版本已完成源码实现，但当前超算登录节点执行 `nvcc` 时出现：

```text
bash: nvcc: command not found
```

这说明当前登录节点未提供 CUDA 编译环境，或需要进入 GPU 节点/加载 CUDA 模块后才能编译运行。因此 CUDA 实测数据暂未采集。后续需要在 GPU 队列中提交作业，或加载正确 CUDA module 后补充实验结果。

---

## 8. 程序化展示场景

为了提升结果展示效果，本项目在传统小球场景之外增加了程序化游戏/科幻展示场景：

- `classic`：基础光线追踪小球场景。
- `blackhole`：黑洞、事件视界、吸积盘和星空。
- `city_drive`：秋日城市道路追车风格画面。
- `snow_gt`：雪地赛道超跑风格画面。
- `racing`：简化赛车展示场景。
- `neon`：霓虹反射材质场景。

这些场景不依赖外部游戏资产或商业模型，而是通过程序化几何和像素计算生成，避免版权风险，也便于在 CPU 和 GPU 上进行并行计算。

示例命令：

```bash
./v1_serial/v1_serial --width 400 --height 300 --samples 64 --scene blackhole
./v2_openmp/v2_openmp --width 400 --height 300 --samples 64 --scene blackhole
./v3_cuda/v3_cuda --width 400 --height 300 --samples 64 --scene blackhole --output results/v3_output.ppm
```

当前项目中已有的预览结果包括：

- `results/showcase_blackhole_preview.png`
- `results/showcase_city_drive_preview.png`
- `results/showcase_snow_gt_preview.png`
- `results/hpc_output_1.png`
- `results/hpc_output_3.png`

---

## 9. 实验环境

当前已测试环境：

- 超算登录节点：`login03`
- 编译器：`g++`
- 并行库：OpenMP
- CUDA：登录节点暂未找到 `nvcc`

已成功执行的编译命令：

```bash
g++ -O2 -std=c++17 v1_serial/main.cpp -o v1_serial/v1_serial
g++ -O2 -std=c++17 -fopenmp v2_openmp/main.cpp -o v2_openmp/v2_openmp
```

CUDA 编译命令设计为：

```bash
nvcc -O3 -arch=sm_80 v3_cuda/main.cu -o v3_cuda/v3_cuda
```

但当前登录节点执行时提示 `nvcc: command not found`，因此 CUDA 部分待 GPU 节点环境恢复后继续测试。

---

## 10. 实验结果

当前已获得的超算平台实验数据如下。

测试参数：

```text
分辨率：400 x 300
采样数：64
最大递归深度：50
```

| 版本 | 线程数 | 运行时间 / s | 相对串行加速比 |
|---|---:|---:|---:|
| V1 Serial | 1 | 38.2367 | 1.00 |
| V2 OpenMP | 8 | 9.72958 | 3.93 |
| V3 CUDA | GPU | 待补充 | 待补充 |

加速比计算公式为：

```text
Speedup = T_serial / T_parallel
```

根据已有数据：

```text
Speedup(8 threads) = 38.2367 / 9.72958 ≈ 3.93
```

并行效率计算公式为：

```text
Efficiency = Speedup / p
```

OpenMP 8 线程并行效率为：

```text
Efficiency(8 threads) = 3.93 / 8 ≈ 49.1%
```

---

## 11. 结果分析

从已有测试结果看，OpenMP 版本相比串行版本有明显加速。在 `400 x 300` 分辨率、`64` 采样数下，8 线程版本运行时间从 `38.2367 s` 降低到 `9.72958 s`，加速比约为 `3.93x`。

加速比低于理想线性加速，主要原因包括：

1. **串行部分开销**  
   场景初始化、文件输出、程序启动和结束等部分无法完全并行化。

2. **负载不均衡**  
   不同像素的光线可能发生不同次数的反射、折射和散射，计算量不同。

3. **线程调度开销**  
   OpenMP 动态调度可以缓解负载不均，但也会引入一定调度成本。

4. **内存访问和缓存影响**  
   多线程同时访问场景数据和 framebuffer 时，会受到缓存和内存带宽影响。

5. **随机数生成开销**  
   每个像素多次采样，需要大量随机数。随机数生成本身也会占据一定时间。

---

## 12. CUDA 预期分析

CUDA 版本尚未获得实测数据，但从算法结构上看，该任务适合 GPU 加速：

- 每个像素计算相对独立。
- 像素数量大，适合映射到大量 GPU 线程。
- 光线追踪计算密集，GPU 可以利用大量并行核心提升吞吐量。

同时，CUDA 版本也可能受到以下因素影响：

- 反射、折射和漫反射分支会造成 warp divergence。
- 不同像素递归深度不同，导致线程执行时间不一致。
- 随机数状态 `curandState` 会增加显存访问和寄存器压力。
- framebuffer 写入虽然较规则，但场景求交计算仍会产生较多分支。

后续如果 GPU 节点可用，可以使用以下命令补充数据：

```bash
qsub scripts/submit_gpu.pbs
```

或在 GPU 节点手动运行：

```bash
module load cuda/12.0
nvcc -O3 -arch=sm_80 v3_cuda/main.cu -o v3_cuda/v3_cuda
./v3_cuda/v3_cuda --width 400 --height 300 --samples 64 --scene blackhole --output results/v3_output.ppm
```

---

## 13. Amdahl 定律分析

Amdahl 定律用于描述固定问题规模下并行程序的理论加速上限：

```text
S(p) = 1 / (f + (1 - f) / p)
```

其中：

- `S(p)` 为使用 `p` 个处理单元时的加速比。
- `f` 为程序中不可并行的串行部分比例。

根据已有 OpenMP 8 线程实验结果：

```text
S(8) ≈ 3.93
```

代入 Amdahl 定律可以估算串行比例：

```text
1 / 3.93 = f + (1 - f) / 8
```

解得：

```text
f ≈ 14.5%
```

该估算说明，在当前实验规模和实现方式下，程序中仍存在一定比例的串行开销和并行损耗。这也解释了为什么 8 线程加速比低于理想值 `8x`。

---

## 14. 遇到的问题与解决思路

### 14.1 CUDA 编译器不可用

在超算登录节点执行：

```bash
nvcc -O3 -arch=sm_80 v3_cuda/main.cu -o v3_cuda/v3_cuda
```

得到报错：

```text
bash: nvcc: command not found
```

初步判断原因是当前位于登录节点 `login03`，未加载 CUDA 环境，或 CUDA 仅在 GPU 计算节点可用。

解决思路：

1. 使用 `module avail cuda` 查看可用 CUDA 模块。
2. 使用 `module load cuda/版本号` 加载 CUDA。
3. 如果登录节点仍不可用，则通过 `qsub scripts/submit_gpu.pbs` 提交 GPU 队列。
4. 作业结束后查看 `.o`、`.e` 或 `.out` 文件中的错误信息。

### 14.2 运行参数拼写问题

曾经使用：

```bash
--sample 64
```

实际程序支持的参数为：

```bash
--samples 64
```

由于程序默认采样数也是 `64`，因此该次实验结果未受影响。后续实验应统一使用 `--samples`。

---

## 15. 结论

本实验完成了一个基于光线追踪的渲染器，并实现了串行、OpenMP 和 CUDA 三种版本。其中串行版本和 OpenMP 版本已经在超算平台上成功编译运行，CUDA 版本已完成源码实现但受当前平台 CUDA 环境限制暂未完成实测。

已有实验结果表明，OpenMP 多线程并行可以显著降低渲染时间。在 `400 x 300` 分辨率、`64` 采样数下，8 线程 OpenMP 版本相对串行版本取得约 `3.93x` 的加速。虽然加速比未达到理想线性加速，但已经体现出像素级并行在光线追踪任务中的有效性。

后续工作包括：

- 在 GPU 节点补充 CUDA 实测数据。
- 完整测试 OpenMP 在 1、2、4、8、16、32 线程下的扩展性。
- 使用更高分辨率和采样数生成最终展示图。
- 绘制加速比曲线和 V1/V2/V3 对比柱状图。
- 如时间允许，加入 OBJ 模型加载或 BVH 加速结构，提升场景复杂度和渲染效率。

---

## 附录 A：常用运行命令

编译：

```bash
g++ -O2 -std=c++17 v1_serial/main.cpp -o v1_serial/v1_serial
g++ -O2 -std=c++17 -fopenmp v2_openmp/main.cpp -o v2_openmp/v2_openmp
nvcc -O3 -arch=sm_80 v3_cuda/main.cu -o v3_cuda/v3_cuda
```

运行串行版本：

```bash
./v1_serial/v1_serial --width 400 --height 300 --samples 64 --scene blackhole
```

运行 OpenMP 版本：

```bash
OMP_NUM_THREADS=8 ./v2_openmp/v2_openmp --width 400 --height 300 --samples 64 --scene blackhole
```

运行 CUDA 版本：

```bash
./v3_cuda/v3_cuda --width 400 --height 300 --samples 64 --scene blackhole --output results/v3_output.ppm
```

自动 benchmark：

```bash
WIDTH=400 HEIGHT=300 SAMPLES=64 SCENE=blackhole bash scripts/run_benchmark.sh
```

---

## 附录 B：当前可插入报告的图片

以下图片已经位于 `results/` 目录，可用于报告或答辩 PPT：

```text
results/showcase_blackhole_preview.png
results/showcase_city_drive_preview.png
results/showcase_snow_gt_preview.png
results/hpc_output_1.png
results/hpc_output_3.png
```

如果需要将 PPM 转换为 PNG，可以使用：

```bash
sips -s format png input.ppm --out output.png
```

或在 Linux 环境使用 ImageMagick：

```bash
magick input.ppm output.png
```
