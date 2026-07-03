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
  line: "#dbe4ee",
};

async function bytes(rel) {
  return await fs.readFile(path.join(ROOT, rel));
}

function text(slide, value, left, top, width, height, options = {}) {
  const shape = slide.shapes.add({
    geometry: "textbox",
    position: { left, top, width, height },
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  shape.text = value;
  shape.text.style = {
    fontSize: options.fontSize ?? 24,
    bold: options.bold ?? false,
    color: options.color ?? C.ink,
    alignment: options.alignment ?? "left",
  };
  return shape;
}

function title(slide, value, kicker = "") {
  if (kicker) text(slide, kicker, 72, 48, 600, 30, { fontSize: 16, bold: true, color: C.blue });
  text(slide, value, 72, 82, 980, 64, { fontSize: 38, bold: true, color: C.ink });
  slide.shapes.add({
    geometry: "line",
    position: { left: 72, top: 154, width: 180, height: 0 },
    fill: "none",
    line: { style: "solid", fill: C.orange, width: 4 },
  });
}

function bulletList(slide, items, left, top, width, options = {}) {
  const lineHeight = options.lineHeight ?? 42;
  items.forEach((item, index) => {
    const y = top + index * lineHeight;
    slide.shapes.add({
      geometry: "ellipse",
      position: { left, top: y + 11, width: 10, height: 10 },
      fill: options.dotColor ?? C.blue,
      line: { style: "solid", fill: "none", width: 0 },
    });
    text(slide, item, left + 24, y, width - 24, lineHeight, {
      fontSize: options.fontSize ?? 23,
      color: options.color ?? C.ink,
    });
  });
}

function metric(slide, label, value, note, left, top, color) {
  slide.shapes.add({
    geometry: "roundRect",
    position: { left, top, width: 330, height: 142 },
    fill: "white",
    line: { style: "solid", fill: C.line, width: 1 },
    borderRadius: "rounded-xl",
    shadow: "shadow-sm",
  });
  text(slide, value, left + 28, top + 22, 270, 48, { fontSize: 34, bold: true, color });
  text(slide, label, left + 28, top + 72, 270, 30, { fontSize: 20, bold: true, color: C.ink });
  text(slide, note, left + 28, top + 104, 270, 24, { fontSize: 15, color: C.muted });
}

async function addImage(slide, rel, left, top, width, height, alt, fit = "cover") {
  slide.images.add({
    blob: await bytes(rel),
    contentType: rel.endsWith(".jpg") ? "image/jpeg" : "image/png",
    alt,
    fit,
    geometry: "roundRect",
    borderRadius: "rounded-lg",
    position: { left, top, width, height },
  });
}

async function main() {
  await fs.mkdir(QA_DIR, { recursive: true });
  const deck = Presentation.create({ slideSize: { width: W, height: H } });

  let s = deck.slides.add();
  s.background.fill = C.pale;
  text(s, "高性能计算课程设计", 72, 56, 520, 36, { fontSize: 20, bold: true, color: C.blue });
  text(s, "光线追踪渲染器的\n并行优化", 72, 142, 610, 138, { fontSize: 48, bold: true, color: C.ink });
  text(s, "串行基准  OpenMP 多线程  CUDA GPU", 72, 292, 620, 42, { fontSize: 25, color: C.muted });
  await addImage(s, "results/showcase_city_drive_preview.png", 720, 86, 488, 394, "城市追车渲染预览");
  metric(s, "OpenMP 加速比", "4.02x", "400 x 300, 64 samples, 8 threads", 72, 492, C.orange);
  metric(s, "优化目标", "像素级并行", "每个像素可独立追踪光线", 426, 492, C.blue);
  metric(s, "CUDA 状态", "已编译提交", "通过 Slurm 进入 GPU 队列", 780, 492, C.cyan);

  s = deck.slides.add();
  s.background.fill = "white";
  title(s, "为什么选择光线追踪作为优化对象", "研究背景与意义");
  bulletList(s, [
    "光线追踪能生成真实的反射、折射、阴影和景深效果",
    "每个像素需要多次采样和多轮相交计算，计算密度高",
    "像素之间天然独立，适合 CPU 多线程和 GPU 大规模并行",
    "实验结果可以同时体现性能提升和图形渲染效果变化",
  ], 90, 210, 560);
  await addImage(s, "results/showcase_blackhole_preview.png", 720, 192, 450, 300, "黑洞吸积盘渲染预览");
  text(s, "目标：用高性能计算技术优化一个可运行的渲染程序，并分析不同并行方案的收益与限制。", 144, 584, 980, 42, {
    fontSize: 24,
    bold: true,
    color: C.ink,
    alignment: "center",
  });

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
    s.shapes.add({
      geometry: "roundRect",
      position: { left, top: 232, width: 300, height: 170 },
      fill: "white",
      line: { style: "solid", fill: C.line, width: 1 },
      borderRadius: "rounded-xl",
      shadow: "shadow-sm",
    });
    text(s, head, left + 28, 258, 244, 38, { fontSize: 28, bold: true, color: i === 0 ? C.ink : i === 1 ? C.orange : C.blue });
    text(s, body, left + 28, 312, 244, 58, { fontSize: 20, color: C.muted });
    if (i < 2) {
      text(s, "→", left + 316, 292, 40, 42, { fontSize: 34, bold: true, color: C.blue, alignment: "center" });
    }
  });
  text(s, "核心思路：保持相同渲染算法，逐步改变任务调度方式，从而对比并行化带来的性能变化。", 118, 500, 1040, 48, {
    fontSize: 26,
    bold: true,
    color: C.ink,
    alignment: "center",
  });

  s = deck.slides.add();
  s.background.fill = "white";
  title(s, "OpenMP 优化把独立像素分配给多个 CPU 线程", "实现方法");
  bulletList(s, [
    "先将像素颜色写入 framebuffer，避免多线程同时写文件",
    "使用 parallel for 并行图像行循环",
    "使用 dynamic 调度缓解不同像素追踪深度不一致的问题",
    "通过 OMP_NUM_THREADS 控制线程数，便于做扩展性分析",
  ], 86, 210, 540, { fontSize: 22 });
  text(s, "#pragma omp parallel for schedule(dynamic, 1)\nfor (int j = 0; j < HEIGHT; j++) {\n    for (int i = 0; i < WIDTH; i++) {\n        framebuffer[row * WIDTH + i] = color;\n    }\n}", 700, 212, 460, 210, {
    fontSize: 21,
    color: C.ink,
  });
  await addImage(s, "results/report_assets/terminal_openmp.png", 700, 462, 460, 164, "OpenMP 运行截图", "contain");

  s = deck.slides.add();
  s.background.fill = C.pale;
  title(s, "CUDA 版本把像素计算映射到 GPU 线程", "实现方法");
  bulletList(s, [
    "16 x 16 线程块组织二维网格",
    "每个线程独立生成随机采样并计算一个像素颜色",
    "递归光线追踪改为迭代流程，降低 GPU 栈压力",
    "球体与材质通过 cudaMalloc 放入显存，作为 kernel 参数传入",
  ], 86, 204, 580, { fontSize: 22, dotColor: C.cyan });
  text(s, "module load intel/cuda/12.1\nnvcc -O3 -arch=sm_80 v3_cuda/main.cu -o v3_cuda/v3_cuda\nsbatch scripts/submit_gpu_slurm.sh", 700, 222, 470, 134, {
    fontSize: 19,
    color: C.ink,
  });
  text(s, "登录节点不直接跑 CUDA 程序；正式测试通过 Slurm 提交到 gpu_4090 计算节点。", 700, 398, 460, 78, {
    fontSize: 24,
    bold: true,
    color: C.blue,
  });

  s = deck.slides.add();
  s.background.fill = "white";
  title(s, "已有超算结果显示 OpenMP 获得明显加速", "运行结果");
  s.charts.add("bar", {
    position: { left: 110, top: 202, width: 530, height: 330 },
    categories: ["Serial", "OpenMP 8"],
    series: [{ name: "运行时间 / s", values: [39.1013, 9.72383], fill: C.orange }],
    hasLegend: false,
    dataLabels: { showValue: true, position: "outEnd" },
    yAxis: {
      majorGridlines: { style: "solid", fill: "#e2e8f0", width: 1 },
    },
  });
  metric(s, "串行版本", "39.1013 s", "400 x 300, 64 samples", 732, 206, C.ink);
  metric(s, "OpenMP 版本", "9.72383 s", "8 CPU threads", 732, 374, C.orange);
  text(s, "加速比 = 39.1013 / 9.72383 ≈ 4.02x，并行效率约 50.3%。", 138, 592, 1000, 42, {
    fontSize: 26,
    bold: true,
    color: C.ink,
    alignment: "center",
  });

  s = deck.slides.add();
  s.background.fill = C.pale;
  title(s, "渲染结果覆盖基础验证和游戏化展示场景", "结果展示");
  await addImage(s, "results/report_assets/hpc_output_1.jpg", 82, 196, 330, 248, "超算输出 1");
  await addImage(s, "results/report_assets/hpc_output_3.jpg", 474, 196, 330, 248, "超算输出 2");
  await addImage(s, "results/showcase_snow_gt_preview.png", 866, 196, 330, 248, "雪地赛道展示图");
  text(s, "PPM 输出可直接在超算生成；报告中已转为 JPG/PNG 便于展示。扩展场景使用程序生成，不依赖商业游戏素材。", 104, 520, 1070, 52, {
    fontSize: 25,
    bold: true,
    color: C.ink,
    alignment: "center",
  });

  s = deck.slides.add();
  s.background.fill = "white";
  title(s, "课程设计已经形成可复现的提交包", "总结");
  bulletList(s, [
    "完成串行、OpenMP、CUDA 三个版本的源码与运行说明",
    "完成超算 CPU/OpenMP 实测，OpenMP 8 线程加速约 4.02 倍",
    "CUDA 已解决编译问题，并按平台要求通过 Slurm 提交 GPU 队列",
    "提交材料包含源代码、实验报告、答辩 PPT PDF 和结果图片",
  ], 120, 214, 880, { fontSize: 25, lineHeight: 50, dotColor: C.orange });
  text(s, "后续可继续补充 CUDA 最终运行时间、OBJ 模型加载和 BVH 加速结构。", 146, 570, 960, 44, {
    fontSize: 27,
    bold: true,
    color: C.blue,
    alignment: "center",
  });

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
