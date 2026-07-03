# 游戏与科幻渲染展示场景说明

项目现在支持多组原创程序化展示场景，用于把高性能并行渲染从“随机小球”升级到更有视觉冲击的游戏/科幻画面。

## 场景选择

```bash
--scene classic
--scene blackhole
--scene city_drive
--scene snow_gt
--scene racing
--scene neon
```

- `classic`：默认小球场景，适合基础正确性和性能对比。
- `blackhole`：黑洞、事件视界、吸积盘、光环和星空，适合科幻封面图。
- `city_drive`：秋日城市追车画面，包含道路透视、楼群、橙色树影、运动模糊和车身高光。
- `snow_gt`：雪地赛道超跑画面，包含冷色树林、雪地高速背景、白色车身和尾翼。
- `racing`：简化赛车展示场景，适合快速调试。
- `neon`：霓虹反射材质展示场景。

这些场景都是原创程序化生成，不依赖外部游戏模型、贴图、Logo 或截图素材。

## 推荐生成命令

小图快速测试：

```bash
./v3_cuda/v3_cuda --width 800 --height 450 --samples 64 --scene blackhole --output results/blackhole_test.ppm
./v3_cuda/v3_cuda --width 800 --height 450 --samples 64 --scene city_drive --output results/city_drive_test.ppm
./v3_cuda/v3_cuda --width 800 --height 450 --samples 64 --scene snow_gt --output results/snow_gt_test.ppm
```

答辩展示图：

```bash
./v3_cuda/v3_cuda --width 1920 --height 1080 --samples 512 --scene blackhole --output results/blackhole_1080p.ppm
./v3_cuda/v3_cuda --width 1920 --height 1080 --samples 512 --scene city_drive --output results/city_drive_1080p.ppm
./v3_cuda/v3_cuda --width 1920 --height 1080 --samples 512 --scene snow_gt --output results/snow_gt_1080p.ppm
```

一键生成三张展示图：

```bash
WIDTH=1920 HEIGHT=1080 SAMPLES=512 CUDA_ARCH=sm_80 bash scripts/render_showcases.sh
```

性能测试示例：

```bash
WIDTH=1200 HEIGHT=800 SAMPLES=256 SCENE=blackhole CUDA_ARCH=sm_80 bash scripts/run_benchmark.sh
python3 scripts/plot_speedup.py
```

## 报告写法建议

可以这样描述：

```text
本实验在基础光线追踪框架上扩展了程序化游戏/科幻展示场景，包括黑洞吸积盘、城市追车和雪地赛道超跑。每个像素独立计算颜色，天然适合 OpenMP 和 CUDA 并行。通过比较串行、CPU 多线程和 GPU 大规模并行版本，验证高性能计算技术在图形渲染任务中的加速效果。
```

这样既能保留课程的并行计算重点，也能让结果图更像完整的图形渲染展示。
