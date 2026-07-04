import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Presentation, PresentationFile } from "@oai/artifact-tool";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = process.env.PROJECT_ROOT
  ? path.resolve(process.env.PROJECT_ROOT)
  : path.resolve(__dirname, "..");
const OUT = path.join(ROOT, "高性能计算光线追踪渲染器答辩PPT.pptx");
const QA_DIR = path.join(ROOT, "results", "ppt_qa");

const W = 1280;
const H = 720;
const C = {
  ink: "#0f172a",
  muted: "#64748b",
  blue: "#1d4ed8",
  cyan: "#0891b2",
  orange: "#ea580c",
  pale: "#f8fafc",
  softBlue: "#eef6ff",
  softOrange: "#fff7ed",
  line: "#dbe4ee",
  dark: "#07111f",
  white: "#ffffff",
};

async function bytes(rel) {
  return await fs.readFile(path.join(ROOT, rel));
}

function shape(slide, left, top, width, height, fill = "white", line = C.line) {
  return slide.shapes.add({
    geometry: "roundRect",
    position: { left, top, width, height },
    fill,
    line: { style: "solid", fill: line, width: 1 },
    borderRadius: "rounded-xl",
    shadow: "shadow-sm",
  });
}

function text(slide, value, left, top, width, height, options = {}) {
  const box = slide.shapes.add({
    geometry: "textbox",
    position: { left, top, width, height },
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  box.text = value;
  box.text.style = {
    fontSize: options.fontSize ?? 24,
    bold: options.bold ?? false,
    color: options.color ?? C.ink,
    alignment: options.alignment ?? "left",
  };
  return box;
}

function title(slide, value, kicker = "") {
  if (kicker) text(slide, kicker, 72, 44, 720, 28, { fontSize: 15, bold: true, color: C.blue });
  text(slide, value, 72, 78, 1040, 62, { fontSize: 36, bold: true, color: C.ink });
  slide.shapes.add({
    geometry: "line",
    position: { left: 72, top: 150, width: 168, height: 0 },
    fill: "none",
    line: { style: "solid", fill: C.orange, width: 4 },
  });
}

function bulletList(slide, items, left, top, width, options = {}) {
  const lineHeight = options.lineHeight ?? 39;
  items.forEach((item, index) => {
    const y = top + index * lineHeight;
    slide.shapes.add({
      geometry: "ellipse",
      position: { left, top: y + 11, width: 9, height: 9 },
      fill: options.dotColor ?? C.blue,
      line: { style: "solid", fill: "none", width: 0 },
    });
    text(slide, item, left + 24, y, width - 24, lineHeight, {
      fontSize: options.fontSize ?? 22,
      color: options.color ?? C.ink,
    });
  });
}

function metric(slide, label, value, note, left, top, color, width = 330) {
  shape(slide, left, top, width, 138, "white");
  text(slide, value, left + 26, top + 20, width - 52, 44, { fontSize: 33, bold: true, color });
  text(slide, label, left + 26, top + 69, width - 52, 28, { fontSize: 19, bold: true, color: C.ink });
  text(slide, note, left + 26, top + 100, width - 52, 24, { fontSize: 14, color: C.muted });
}

function code(slide, value, left, top, width, height, fontSize = 17) {
  shape(slide, left, top, width, height, "#f1f5f9", "#cbd5e1");
  text(slide, value, left + 18, top + 16, width - 36, height - 30, {
    fontSize,
    color: "#18324a",
  });
}

async function addImage(slide, rel, left, top, width, height, alt, fit = "cover", radius = "rounded-lg") {
  slide.images.add({
    blob: await bytes(rel),
    contentType: rel.endsWith(".jpg") ? "image/jpeg" : "image/png",
    alt,
    fit,
    geometry: "roundRect",
    borderRadius: radius,
    position: { left, top, width, height },
  });
}

async function imageHero(slide, rel, caption) {
  await addImage(slide, rel, 0, 0, W, H, caption, "cover", "rounded-none");
  slide.shapes.add({
    geometry: "rect",
    position: { left: 0, top: 0, width: W, height: H },
    fill: "#000000/42",
    line: { style: "solid", fill: "none", width: 0 },
  });
}

function sectionFooter(slide, label) {
  text(slide, label, 72, 656, 660, 26, { fontSize: 14, color: C.muted });
  text(slide, "光线追踪渲染器并行优化", 934, 656, 270, 26, {
    fontSize: 14,
    color: C.muted,
    alignment: "right",
  });
}

async function main() {
  await fs.rm(QA_DIR, { recursive: true, force: true });
  await fs.mkdir(QA_DIR, { recursive: true });
  const deck = Presentation.create({ slideSize: { width: W, height: H } });

  let s = deck.slides.add();
  await imageHero(s, "results/presentation_assets/ref_city_car.png", "城市赛车参考图");
  text(s, "高性能计算课程设计 · 第 8 组", 72, 56, 620, 34, { fontSize: 20, bold: true, color: "#bfdbfe" });
  text(s, "光线追踪渲染器的\n并行优化", 72, 138, 640, 150, { fontSize: 52, bold: true, color: C.white });
  text(s, "24281098 胡哲祺 / 24281100 李建宇", 72, 310, 680, 42, { fontSize: 25, color: "#dbeafe" });
  metric(s, "OpenMP 加速比", "4.02x", "400 x 300, 64 samples, 8 threads", 72, 502, C.orange);
  metric(s, "优化对象", "像素级光追", "每个像素可独立追踪光线", 426, 502, C.blue);
  metric(s, "CUDA 加速比", "310.07x", "GPU render time 0.126103 s", 780, 502, C.cyan);

  s = deck.slides.add();
  s.background.fill = "white";
  title(s, "课程设计任务与提交要求", "任务定位");
  bulletList(s, [
    "题目自选：选择光线追踪渲染器作为可优化的现有程序",
    "高性能计算技术：使用 OpenMP 和 CUDA 优化像素计算",
    "可复现材料：保留原始串行代码、优化代码和运行说明",
    "实验报告：覆盖背景、路线、实现、截图、结果与性能分析",
    "答辩材料：用 PDF 展示问题、方法、结果和后续改进方向",
  ], 92, 198, 620, { fontSize: 23, lineHeight: 46 });
  await addImage(s, "results/presentation_assets/ref_blackhole_wide.png", 790, 178, 360, 250, "黑洞参考图");
  metric(s, "最终提交包", "源代码 + 报告 + PPT", "统一版本，方便助教复现", 780, 474, C.blue, 380);
  sectionFooter(s, "目标：把一个能运行的图形程序优化成可测试、可展示、可复现的课程设计");

  s = deck.slides.add();
  s.background.fill = C.pale;
  title(s, "为什么选择光线追踪作为优化对象", "研究背景与意义");
  bulletList(s, [
    "光线追踪能生成反射、折射、阴影和景深等真实感效果",
    "每个像素需要多次采样、求交和材质散射，计算量较高",
    "不同像素基本互不依赖，天然适合并行拆分",
    "输出图像可直接观察，便于同时展示正确性和视觉效果",
  ], 90, 196, 560, { fontSize: 23, lineHeight: 45 });
  await addImage(s, "results/presentation_assets/ref_blackhole_close.png", 720, 166, 460, 318, "黑洞特写参考图");
  text(s, "一句话概括：这是一个计算密集、并行特征明显、结果可视化强的优化题目。", 130, 568, 1010, 38, {
    fontSize: 25,
    bold: true,
    color: C.ink,
    alignment: "center",
  });
  sectionFooter(s, "研究背景");

  s = deck.slides.add();
  s.background.fill = "white";
  title(s, "光线追踪的核心计算流程", "算法原理");
  const flow = [
    ["1. 相机发射光线", "根据像素位置生成 primary ray"],
    ["2. 场景求交", "寻找最近球体交点和法线"],
    ["3. 材质散射", "漫反射、金属反射、玻璃折射"],
    ["4. 多次采样", "抗锯齿并降低随机噪声"],
  ];
  flow.forEach(([head, body], i) => {
    const left = 86 + (i % 2) * 535;
    const top = 196 + Math.floor(i / 2) * 172;
    shape(s, left, top, 440, 120, i % 2 === 0 ? C.softBlue : C.softOrange);
    text(s, head, left + 26, top + 22, 380, 32, { fontSize: 24, bold: true, color: i % 2 === 0 ? C.blue : C.orange });
    text(s, body, left + 26, top + 64, 380, 34, { fontSize: 20, color: C.muted });
  });
  code(s, "for each pixel:\n  color = 0\n  for sample in samples:\n    ray = camera.get_ray(u, v)\n    color += ray_color(ray)\n  write_pixel(color / samples)", 210, 558, 840, 106, 17);

  s = deck.slides.add();
  s.background.fill = C.pale;
  title(s, "项目按三个版本逐步优化", "技术路线");
  const steps = [
    ["V1 Serial", "单线程逐像素追踪，作为性能基准"],
    ["V2 OpenMP", "对像素行循环并行化，利用 CPU 多核"],
    ["V3 CUDA", "每个 GPU thread 负责一个像素，显存保存场景数据"],
  ];
  steps.forEach(([head, body], i) => {
    const left = 112 + i * 374;
    shape(s, left, 232, 300, 170, "white");
    text(s, head, left + 28, 258, 244, 38, { fontSize: 28, bold: true, color: i === 0 ? C.ink : i === 1 ? C.orange : C.blue });
    text(s, body, left + 28, 312, 244, 58, { fontSize: 20, color: C.muted });
    if (i < 2) text(s, "→", left + 316, 292, 40, 42, { fontSize: 34, bold: true, color: C.blue, alignment: "center" });
  });
  text(s, "核心思路：保持相同渲染算法，逐步改变任务调度方式，从而对比并行化带来的性能变化。", 118, 500, 1040, 48, {
    fontSize: 26,
    bold: true,
    color: C.ink,
    alignment: "center",
  });
  sectionFooter(s, "技术路线");

  s = deck.slides.add();
  s.background.fill = "white";
  title(s, "程序结构围绕光线、几何、材质和相机组织", "代码结构");
  const modules = [
    ["vec3", "三维向量运算"],
    ["ray", "光线起点与方向"],
    ["sphere", "球体求交"],
    ["material", "散射与反射折射"],
    ["camera", "视角与景深"],
    ["main", "场景、循环、输出"],
  ];
  modules.forEach(([name, desc], i) => {
    const left = 90 + (i % 3) * 365;
    const top = 190 + Math.floor(i / 3) * 150;
    shape(s, left, top, 290, 104, "white");
    text(s, name, left + 24, top + 20, 240, 32, { fontSize: 27, bold: true, color: i % 2 ? C.orange : C.blue });
    text(s, desc, left + 24, top + 61, 240, 28, { fontSize: 19, color: C.muted });
  });
  text(s, "三套版本保持相似目录结构，便于比较串行逻辑、OpenMP 并行点和 CUDA kernel 改写。", 132, 554, 1010, 42, {
    fontSize: 24,
    bold: true,
    alignment: "center",
  });
  sectionFooter(s, "代码结构");

  s = deck.slides.add();
  s.background.fill = C.pale;
  title(s, "串行版本提供正确性基准和性能基线", "V1 Serial");
  bulletList(s, [
    "逐行逐像素计算颜色，逻辑最直接",
    "每个像素执行 samples 次随机采样",
    "递归追踪光线直到达到最大深度或返回背景色",
    "输出 PPM 文件，适合在超算环境中直接生成",
  ], 86, 204, 520, { fontSize: 22, lineHeight: 43 });
  code(s, "for (int j = HEIGHT - 1; j >= 0; j--) {\n  for (int i = 0; i < WIDTH; i++) {\n    Vec3 color(0, 0, 0);\n    for (int s = 0; s < SAMPLES; s++) {\n      Ray r = cam.get_ray(u, v);\n      color += ray_color(r, world, materials, MAX_DEPTH);\n    }\n    write_pixel(out, color, SAMPLES);\n  }\n}", 690, 190, 470, 292, 15);
  await addImage(s, "results/report_assets/terminal_serial.png", 690, 510, 470, 110, "串行运行截图", "contain");

  s = deck.slides.add();
  s.background.fill = "white";
  title(s, "OpenMP 优化把独立像素分配给多个 CPU 线程", "V2 OpenMP");
  bulletList(s, [
    "先将像素颜色写入 framebuffer，避免多线程同时写文件",
    "使用 parallel for 并行图像行循环",
    "使用 dynamic 调度缓解不同像素追踪深度不一致的问题",
    "通过 OMP_NUM_THREADS 控制线程数，便于做扩展性分析",
  ], 86, 210, 540, { fontSize: 22 });
  code(s, "#pragma omp parallel for schedule(dynamic, 1)\nfor (int j = 0; j < HEIGHT; j++) {\n  for (int i = 0; i < WIDTH; i++) {\n    Vec3 color(0, 0, 0);\n    framebuffer[row * WIDTH + i] = color;\n  }\n}", 700, 200, 460, 226, 16);
  await addImage(s, "results/report_assets/terminal_openmp.png", 700, 462, 460, 164, "OpenMP 运行截图", "contain");

  s = deck.slides.add();
  s.background.fill = C.pale;
  title(s, "CUDA 版本把像素计算映射到 GPU 线程", "V3 CUDA");
  bulletList(s, [
    "16 x 16 线程块组织二维网格",
    "每个线程独立生成随机采样并计算一个像素颜色",
    "递归 ray_color 改为迭代形式，降低 GPU 栈压力",
    "球体与材质通过 cudaMalloc 放入显存，作为 kernel 参数传入",
  ], 86, 204, 580, { fontSize: 22, dotColor: C.cyan });
  code(s, "module load intel/cuda/12.1\nnvcc -O3 -arch=sm_80 v3_cuda/main.cu -o v3_cuda/v3_cuda\nsbatch scripts/submit_gpu_slurm.sh\nsqueue -u bjtu3", 700, 208, 470, 152, 17);
  text(s, "登录节点不直接跑 CUDA 程序；正式测试通过 Slurm 提交到 gpu_4090 计算节点。", 700, 410, 460, 78, {
    fontSize: 24,
    bold: true,
    color: C.blue,
  });
  sectionFooter(s, "CUDA 实现");

  s = deck.slides.add();
  s.background.fill = "white";
  title(s, "CUDA 内存设计修复了结构体动态初始化问题", "关键问题处理");
  bulletList(s, [
    "早期版本将 Sphere / MaterialData 放入 __constant__ 数组",
    "结构体中包含 Vec3 构造逻辑，导致 nvcc 报动态初始化错误",
    "修复方式：在 host 端构建场景，再 cudaMalloc + cudaMemcpy 到显存",
    "kernel 参数显式传入 spheres、materials 和 num_spheres",
  ], 82, 196, 560, { fontSize: 22, lineHeight: 43 });
  code(s, "Sphere* d_spheres = nullptr;\nMaterialData* d_materials = nullptr;\ncudaMalloc(&d_spheres, spheres.size() * sizeof(Sphere));\ncudaMalloc(&d_materials, materials.size() * sizeof(MaterialData));\ncudaMemcpy(d_spheres, spheres.data(), bytes, cudaMemcpyHostToDevice);\nrender_kernel<<<grid, block>>>(..., d_spheres, num_spheres, d_materials);", 700, 190, 466, 290, 14);
  metric(s, "结果", "可编译", "intel/cuda/12.1 + nvcc", 700, 516, C.cyan, 220);
  metric(s, "收益", "更稳定", "避免 __constant__ 初始化限制", 946, 516, C.orange, 220);

  s = deck.slides.add();
  s.background.fill = C.pale;
  title(s, "超算平台运行流程分为登录节点编译和 GPU 队列执行", "实验平台");
  const ops = [
    ["1. 进入目录", "cd data/24281100/2"],
    ["2. 加载 CUDA", "module load intel/cuda/12.1"],
    ["3. 编译程序", "nvcc -O3 -arch=sm_80 ..."],
    ["4. 提交作业", "sbatch submit.sh"],
    ["5. 查看队列", "squeue -u bjtu3"],
  ];
  ops.forEach(([head, body], i) => {
    const left = 88 + (i % 5) * 226;
    shape(s, left, 218, 186, 148, "white");
    text(s, head, left + 18, 240, 150, 30, { fontSize: 20, bold: true, color: C.blue });
    text(s, body, left + 18, 290, 150, 44, { fontSize: 16, color: C.muted });
  });
  text(s, "CUDA driver version is insufficient for CUDA runtime version 出现在登录节点直接运行时；提交到 GPU 计算节点后不再作为代码错误处理。", 124, 492, 1030, 58, {
    fontSize: 24,
    bold: true,
    color: C.ink,
    alignment: "center",
  });

  s = deck.slides.add();
  s.background.fill = "white";
  title(s, "已有超算结果显示 GPU 并行获得数量级加速", "运行结果");
  s.charts.add("bar", {
    position: { left: 82, top: 202, width: 570, height: 330 },
    categories: ["Serial", "OpenMP 8", "CUDA"],
    series: [{ name: "运行时间 / s", values: [39.1013, 9.72383, 0.126103], fill: C.orange }],
    hasLegend: false,
    dataLabels: { showValue: true, position: "outEnd" },
    yAxis: { majorGridlines: { style: "solid", fill: "#e2e8f0", width: 1 } },
  });
  metric(s, "串行版本", "39.1013 s", "400 x 300, 64 samples", 718, 180, C.ink, 230);
  metric(s, "OpenMP 版本", "9.72383 s", "8 CPU threads", 972, 180, C.orange, 230);
  metric(s, "CUDA 版本", "0.126103 s", "gpu_4090 分区", 846, 356, C.cyan, 230);
  text(s, "OpenMP 加速约 4.02x；CUDA 相对串行加速约 310.07x。", 138, 592, 1000, 42, {
    fontSize: 26,
    bold: true,
    color: C.ink,
    alignment: "center",
  });

  s = deck.slides.add();
  s.background.fill = C.pale;
  title(s, "性能提升来自像素级并行，CUDA 进一步放大并发规模", "性能分析");
  bulletList(s, [
    "像素计算独立，因此并行化收益明显",
    "文件输出、场景初始化和部分统计仍是串行部分",
    "不同像素反射/折射次数不同，导致负载不均",
    "随机数生成、调度和缓存访问会引入额外开销",
    "线程数继续增大后，内存带宽和调度开销会限制收益",
  ], 92, 188, 610, { fontSize: 22, lineHeight: 44, dotColor: C.orange });
  metric(s, "OpenMP 加速比", "4.02x", "T_serial / T_openmp", 770, 168, C.orange, 330);
  metric(s, "CUDA 加速比", "310.07x", "T_serial / T_cuda", 770, 318, C.cyan, 330);
  metric(s, "OpenMP 效率", "50.3%", "Speedup / 8 threads", 770, 468, C.blue, 330);
  text(s, "结论：OpenMP 验证 CPU 多核收益，CUDA 体现 GPU 大规模线程并行优势。", 116, 620, 1040, 38, {
    fontSize: 24,
    bold: true,
    alignment: "center",
  });

  s = deck.slides.add();
  s.background.fill = "white";
  title(s, "PPM 输出用于正确性验证，JPG/PNG 用于报告展示", "结果图片");
  await addImage(s, "results/report_assets/hpc_output_1.jpg", 82, 196, 330, 248, "超算输出 1");
  await addImage(s, "results/report_assets/hpc_output_3.jpg", 474, 196, 330, 248, "超算输出 2");
  await addImage(s, "results/showcase_snow_gt_preview.png", 866, 196, 330, 248, "雪地赛道展示图");
  text(s, "PPM 适合超算环境直接输出；报告中将关键 PPM 转为 JPG，并保留 PNG 预览图。", 110, 514, 1040, 42, {
    fontSize: 25,
    bold: true,
    color: C.ink,
    alignment: "center",
  });

  s = deck.slides.add();
  await imageHero(s, "results/presentation_assets/ref_snow_car.png", "雪地赛车参考图");
  text(s, "展示目标：从基础小球走向更像游戏画面的渲染效果", 72, 70, 950, 52, {
    fontSize: 35,
    bold: true,
    color: C.white,
  });
  text(s, "参考画面强调高速运动、雪地反射、车身高光和背景运动模糊。项目中的 snow_gt / racing 场景用程序化几何近似这些视觉特征。", 72, 536, 980, 72, {
    fontSize: 25,
    bold: true,
    color: "#e0f2fe",
  });

  s = deck.slides.add();
  await imageHero(s, "results/presentation_assets/ref_city_car.png", "城市赛车参考图");
  text(s, "城市追车场景用于展示光照、反射和景深氛围", 72, 72, 920, 52, {
    fontSize: 35,
    bold: true,
    color: C.white,
  });
  text(s, "当前项目不使用商业游戏资源；画面素材作为答辩参考图，程序输出由球体、材质和像素着色过程生成。", 72, 545, 1040, 62, {
    fontSize: 25,
    bold: true,
    color: "#ffedd5",
  });

  s = deck.slides.add();
  await imageHero(s, "results/presentation_assets/ref_blackhole_wide.png", "黑洞参考图");
  text(s, "黑洞场景用于展示程序化像素着色能力", 72, 74, 920, 52, {
    fontSize: 36,
    bold: true,
    color: C.white,
  });
  text(s, "黑洞/吸积盘展示图不依赖复杂 OBJ 模型，主要通过像素函数、噪声、环形结构和高亮边缘形成视觉效果。", 72, 550, 1020, 60, {
    fontSize: 25,
    bold: true,
    color: "#fed7aa",
  });

  s = deck.slides.add();
  s.background.fill = C.pale;
  title(s, "复现步骤已经整理进提交包", "复现方法");
  code(s, "g++ -O2 -std=c++17 v1_serial/main.cpp -o v1_serial/v1_serial\ng++ -O2 -std=c++17 -fopenmp v2_openmp/main.cpp -o v2_openmp/v2_openmp\nmodule load intel/cuda/12.1\nnvcc -O3 -arch=sm_80 v3_cuda/main.cu -o v3_cuda/v3_cuda\nOMP_NUM_THREADS=8 ./v2_openmp/v2_openmp --width 400 --height 300 --samples 64\nsbatch scripts/submit_gpu_slurm.sh", 96, 186, 760, 260, 17);
  bulletList(s, [
    "SUBMISSION_README.md：给助教的最短复现说明",
    "EXPERIMENT_GUIDE.md：完整实验步骤和常见问题",
    "SUPERCOMPUTER_GUIDE.md：iNode、上传、module 和队列说明",
    "scripts/run_benchmark.sh：统一编译和记录性能数据",
  ], 90, 492, 720, { fontSize: 21, lineHeight: 38 });
  metric(s, "压缩包", "统一版本", "组内提交内容保持一致", 904, 246, C.blue, 260);

  s = deck.slides.add();
  s.background.fill = "white";
  title(s, "目前不足与后续改进方向", "工作展望");
  bulletList(s, [
    "补充 CUDA 最终运行时间，形成完整 Serial/OpenMP/CUDA 性能对比",
    "加入 OBJ 模型加载，让车体从程序化球体过渡到真实三角网格",
    "加入 BVH 加速结构，降低大量物体场景中的求交复杂度",
    "进一步采集不同分辨率、采样数和线程数下的扩展性数据",
    "将展示场景继续向实时游戏渲染风格靠近",
  ], 96, 190, 690, { fontSize: 22, lineHeight: 45 });
  await addImage(s, "results/presentation_assets/ref_blackhole_close.png", 824, 192, 330, 248, "黑洞参考图");
  await addImage(s, "results/presentation_assets/ref_snow_car.png", 824, 470, 330, 150, "赛车参考图");

  s = deck.slides.add();
  s.background.fill = C.pale;
  title(s, "课程设计已经形成可复现的提交包", "总结");
  bulletList(s, [
    "完成串行、OpenMP、CUDA 三个版本的源码与运行说明",
    "完成超算 CPU/OpenMP/CUDA 实测，CUDA 相对串行加速约 310.07 倍",
    "CUDA 已完成 GPU 队列实测，运行时间为 0.126103 s",
    "报告中插入运行截图、结果图片、代码片段和性能分析",
    "答辩 PDF 扩展为完整展示版，突出高性能计算和游戏渲染方向",
  ], 116, 190, 820, { fontSize: 24, lineHeight: 48, dotColor: C.orange });
  metric(s, "最终材料", "代码 / 报告 / PPT", "第 8 组统一版本", 842, 498, C.blue, 300);
  text(s, "谢谢老师和同学！", 116, 610, 600, 42, { fontSize: 32, bold: true, color: C.ink });

  for (const [index, slide] of deck.slides.items.entries()) {
    const png = await deck.export({ slide, format: "png", scale: 1 });
    await fs.writeFile(path.join(QA_DIR, `slide-${String(index + 1).padStart(2, "0")}.png`), new Uint8Array(await png.arrayBuffer()));
  }
  const montage = await deck.export({ format: "webp", montage: true, scale: 1 });
  await fs.writeFile(path.join(QA_DIR, "montage.webp"), new Uint8Array(await montage.arrayBuffer()));

  const pptx = await PresentationFile.exportPptx(deck);
  await pptx.save(OUT);
  console.log(OUT);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
