from pathlib import Path
import math
import shutil

from PIL import Image
from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
ASSETS = RESULTS / "report_assets"
OUT = ROOT / "高性能计算光线追踪渲染器实验报告.docx"

SCREENSHOT_SERIAL = Path(
    "/Users/canghe/Library/Containers/com.tencent.xinWeChat/Data/Documents/"
    "xwechat_files/wxid_fbhucv2so65n12_7368/temp/RWTemp/2026-07/"
    "b89452a51d35f5f02eade11c067c81c4.png"
)
SCREENSHOT_OPENMP = Path(
    "/Users/canghe/Library/Containers/com.tencent.xinWeChat/Data/Documents/"
    "xwechat_files/wxid_fbhucv2so65n12_7368/temp/RWTemp/2026-07/"
    "75f51280-6bfb-49be-9625-6d25eab7a32a/1.png"
)


def ensure_assets():
    ASSETS.mkdir(parents=True, exist_ok=True)
    copies = {}

    for src, name in [
        (SCREENSHOT_SERIAL, "terminal_serial.png"),
        (SCREENSHOT_OPENMP, "terminal_openmp.png"),
        (RESULTS / "hpc_output_1.png", "hpc_output_1.png"),
        (RESULTS / "hpc_output_3.png", "hpc_output_3.png"),
        (RESULTS / "showcase_blackhole_preview.png", "showcase_blackhole_preview.png"),
        (RESULTS / "showcase_city_drive_preview.png", "showcase_city_drive_preview.png"),
        (RESULTS / "showcase_snow_gt_preview.png", "showcase_snow_gt_preview.png"),
    ]:
        if src.exists():
            dst = ASSETS / name
            shutil.copyfile(src, dst)
            copies[name] = dst

    for src, name in [
        (RESULTS / "hpc_output_1.ppm", "hpc_output_1.jpg"),
        (RESULTS / "hpc_output_3.ppm", "hpc_output_3.jpg"),
    ]:
        if src.exists():
            dst = ASSETS / name
            im = Image.open(src).convert("RGB")
            im.save(dst, "JPEG", quality=95)
            copies[name] = dst

    return copies


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), fill)
    tc_pr.append(shd)


def set_cell_border(cell, color="D9E2EC"):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    borders = tc_pr.first_child_found_in("w:tcBorders")
    if borders is None:
        borders = OxmlElement("w:tcBorders")
        tc_pr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        tag = "w:{}".format(edge)
        element = borders.find(qn(tag))
        if element is None:
            element = OxmlElement(tag)
            borders.append(element)
        element.set(qn("w:val"), "single")
        element.set(qn("w:sz"), "4")
        element.set(qn("w:space"), "0")
        element.set(qn("w:color"), color)


def set_east_asia_font(run_or_style, font_name):
    element = run_or_style._element
    r_pr = element.get_or_add_rPr()
    r_fonts = r_pr.rFonts
    if r_fonts is None:
        r_fonts = OxmlElement("w:rFonts")
        r_pr.append(r_fonts)
    r_fonts.set(qn("w:eastAsia"), font_name)


def set_table_width(table):
    tbl = table._tbl
    tbl_pr = tbl.tblPr
    tbl_w = tbl_pr.first_child_found_in("w:tblW")
    if tbl_w is None:
        tbl_w = OxmlElement("w:tblW")
        tbl_pr.append(tbl_w)
    tbl_w.set(qn("w:w"), "9360")
    tbl_w.set(qn("w:type"), "dxa")


def style_doc(doc):
    section = doc.sections[0]
    section.top_margin = Inches(0.75)
    section.bottom_margin = Inches(0.75)
    section.left_margin = Inches(0.85)
    section.right_margin = Inches(0.85)

    styles = doc.styles
    normal = styles["Normal"]
    normal.font.name = "Calibri"
    set_east_asia_font(normal, "宋体")
    normal.font.size = Pt(10.5)
    normal.paragraph_format.line_spacing = 1.12
    normal.paragraph_format.space_after = Pt(5)

    for style_name, size, color, before, after in [
        ("Heading 1", 16, "1F4D78", 14, 7),
        ("Heading 2", 13, "2E74B5", 10, 5),
        ("Heading 3", 11.5, "1F4D78", 7, 3),
    ]:
        st = styles[style_name]
        st.font.name = "Calibri"
        set_east_asia_font(st, "黑体")
        st.font.size = Pt(size)
        st.font.bold = True
        st.font.color.rgb = RGBColor.from_string(color)
        st.paragraph_format.space_before = Pt(before)
        st.paragraph_format.space_after = Pt(after)
        st.paragraph_format.keep_with_next = True


def add_title(doc):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run("高性能计算大作业实验报告")
    run.bold = True
    run.font.size = Pt(22)
    run.font.color.rgb = RGBColor(31, 77, 120)
    run.font.name = "Calibri"
    set_east_asia_font(run, "黑体")

    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run("光线追踪渲染器的串行、OpenMP 与 CUDA 并行加速")
    run.font.size = Pt(14)
    run.font.color.rgb = RGBColor(80, 80, 80)
    set_east_asia_font(run, "宋体")

    meta = doc.add_table(rows=4, cols=2)
    meta.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_width(meta)
    rows = [
        ("课程方向", "高性能计算 / 图形渲染"),
        ("实现语言", "C++17、OpenMP、CUDA"),
        ("实验平台", "本地开发环境 + 远程超算平台"),
        ("当前状态", "串行与 OpenMP 已完成超算实测；CUDA 版本已可编译，并通过 Slurm 提交 GPU 队列测试"),
    ]
    for row, (k, v) in zip(meta.rows, rows):
        row.cells[0].text = k
        row.cells[1].text = v
        for cell in row.cells:
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            set_cell_border(cell)
            for para in cell.paragraphs:
                para.paragraph_format.space_after = Pt(2)
        set_cell_shading(row.cells[0], "E8EEF5")


def add_para(doc, text):
    p = doc.add_paragraph(text)
    p.paragraph_format.first_line_indent = Pt(21)
    return p


def add_bullets(doc, items):
    for item in items:
        p = doc.add_paragraph(style="List Bullet")
        p.add_run(item)
        p.paragraph_format.space_after = Pt(3)


def add_code(doc, code):
    table = doc.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_width(table)
    cell = table.cell(0, 0)
    set_cell_shading(cell, "F4F6F9")
    set_cell_border(cell, "CBD5E1")
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(4)
    for line_idx, line in enumerate(code.strip("\n").splitlines()):
        if line_idx:
            p.add_run("\n")
        run = p.add_run(line)
        run.font.name = "Menlo"
        set_east_asia_font(run, "Menlo")
        run.font.size = Pt(8.5)
        run.font.color.rgb = RGBColor(20, 40, 60)


def add_caption(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run(text)
    run.italic = True
    run.font.size = Pt(9)
    run.font.color.rgb = RGBColor(90, 90, 90)
    p.paragraph_format.space_after = Pt(6)


def add_image(doc, path, caption, width=6.2):
    if not path or not Path(path).exists():
        return
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.add_run().add_picture(str(path), width=Inches(width))
    add_caption(doc, caption)


def add_two_images(doc, left_path, right_path, left_caption, right_caption):
    table = doc.add_table(rows=2, cols=2)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_width(table)
    for row in table.rows:
        for cell in row.cells:
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            set_cell_border(cell, "FFFFFF")
    for idx, (path, cap) in enumerate([(left_path, left_caption), (right_path, right_caption)]):
        cell = table.cell(0, idx)
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        if path and Path(path).exists():
            p.add_run().add_picture(str(path), width=Inches(3.0))
        cap_cell = table.cell(1, idx)
        p2 = cap_cell.paragraphs[0]
        p2.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p2.add_run(cap)
        r.italic = True
        r.font.size = Pt(9)
        r.font.color.rgb = RGBColor(90, 90, 90)


def add_perf_table(doc):
    serial = 39.1013
    openmp = 9.72383
    speedup = serial / openmp
    efficiency = speedup / 8.0
    table = doc.add_table(rows=1, cols=4)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_width(table)
    headers = ["版本", "线程数", "运行时间 / s", "相对串行加速比"]
    for i, h in enumerate(headers):
        cell = table.rows[0].cells[i]
        cell.text = h
        set_cell_shading(cell, "E8EEF5")
    data = [
        ["V1 Serial", "1", f"{serial:.4f}", "1.00"],
        ["V2 OpenMP", "8", f"{openmp:.5f}", f"{speedup:.2f}"],
        ["V3 CUDA", "GPU", "待补充", "待补充"],
    ]
    for row_data in data:
        row = table.add_row()
        for i, val in enumerate(row_data):
            row.cells[i].text = val
    for row in table.rows:
        for cell in row.cells:
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            set_cell_border(cell)
            for p in cell.paragraphs:
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                p.paragraph_format.space_after = Pt(2)
    add_caption(doc, f"表 1  400×300、64 samples 下的已有超算实测结果；OpenMP 8 线程效率约 {efficiency * 100:.1f}%。")


def add_header_footer(doc):
    section = doc.sections[0]
    header = section.header
    p = header.paragraphs[0]
    p.text = "高性能计算大作业：光线追踪渲染器并行加速"
    p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    for r in p.runs:
        r.font.size = Pt(9)
        r.font.color.rgb = RGBColor(100, 100, 100)
    footer = section.footer
    p = footer.paragraphs[0]
    p.text = "实验报告 · 串行 / OpenMP / CUDA"
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    for r in p.runs:
        r.font.size = Pt(9)
        r.font.color.rgb = RGBColor(120, 120, 120)


def build_doc():
    assets = ensure_assets()
    doc = Document()
    style_doc(doc)
    add_header_footer(doc)
    add_title(doc)

    doc.add_heading("摘要", level=1)
    add_para(
        doc,
        "本实验实现了一个基于光线追踪的渲染器，并完成串行版本、OpenMP 多线程版本和 CUDA GPU 版本的设计与实现。"
        "实验以像素级光线追踪计算为核心任务，通过比较串行和并行版本的运行时间，分析高性能计算技术在图形渲染中的加速效果。"
    )
    add_para(
        doc,
        "当前已在超算平台上完成串行版本和 OpenMP 版本的实测。测试参数为 400×300 分辨率、64 samples，串行版本运行时间为 39.1013 s，"
        "OpenMP 8 线程版本运行时间为 9.72383 s，加速比约为 4.02×。CUDA 版本已经使用 intel/cuda/12.1 模块完成编译，并通过 Slurm 提交到 gpu_4090 分区运行。"
    )

    doc.add_heading("1. 研究背景与意义", level=1)
    add_para(
        doc,
        "光线追踪通过模拟光线与场景物体的相交、反射、折射和散射过程生成图像，能够获得较真实的阴影、反射、透明材质和景深效果。"
        "由于每个像素通常需要发射多条光线并执行递归追踪，计算量随分辨率、采样数和递归深度快速增长，因此非常适合使用 CPU 多线程和 GPU 并行计算进行加速。"
    )
    add_para(
        doc,
        "游戏画面渲染、影视级离线渲染和实时路径追踪都依赖大量相互独立的像素计算。本课程设计选择光线追踪作为优化对象，"
        "可以较直观地体现高性能计算中任务分解、负载均衡、GPU 线程映射和性能加速比分析等核心思想。"
    )

    doc.add_heading("2. 研究内容", level=1)
    add_bullets(
        doc,
        [
            "实现 C++17 串行光线追踪渲染器，作为性能基准。",
            "基于 OpenMP 对像素循环进行并行化，测试 CPU 多核加速效果。",
            "设计 CUDA 版本，将每个像素映射到一个 GPU 线程。",
            "生成渲染结果图，并结合运行截图和性能数据完成实验分析。",
        ],
    )

    doc.add_heading("3. 技术路线与程序结构", level=1)
    add_para(doc, "项目整体采用 V1 串行、V2 OpenMP、V3 CUDA 的递进实现路线。三种版本共享相同的渲染思想，主要差异在于像素计算的调度方式。")
    add_code(
        doc,
        """
V1 串行版 C++ 光线追踪
        ↓  像素循环加 OpenMP parallel for
V2 OpenMP CPU 多线程并行
        ↓  每个 CUDA thread 负责一个像素
V3 CUDA GPU 大规模并行
""",
    )
    add_para(
        doc,
        "核心文件包括 vec3、ray、sphere、material、camera 和 main。场景物体使用球体表示，材质包括漫反射、金属和玻璃。"
        "输出图像采用 PPM 格式，便于在超算环境中直接生成和检查。"
    )

    doc.add_heading("4. 串行版本实现", level=1)
    add_para(doc, "串行版本逐行逐像素计算颜色。每个像素进行多次随机采样，用于抗锯齿和降低噪声。核心循环如下。")
    add_code(
        doc,
        """
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
""",
    )
    add_image(doc, assets.get("terminal_serial.png"), "图 1  超算平台串行版本编译与运行截图：400×300、64 samples，运行时间 39.1013 s。", 6.4)

    doc.add_heading("5. OpenMP 并行版本实现", level=1)
    add_para(
        doc,
        "OpenMP 版本利用像素之间相互独立的特点，对图像行进行并行计算。为了避免多线程同时写文件，程序先将结果写入 framebuffer，最后统一按顺序输出 PPM。"
    )
    add_code(
        doc,
        """
std::vector<Vec3> framebuffer(static_cast<size_t>(WIDTH) * HEIGHT);

#pragma omp parallel for schedule(dynamic, 1)
for (int j = 0; j < HEIGHT; j++) {
    for (int i = 0; i < WIDTH; i++) {
        Vec3 color(0, 0, 0);
        // 每个像素独立追踪光线
        framebuffer[static_cast<size_t>(out_row) * WIDTH + i] = color;
    }
}
""",
    )
    add_para(
        doc,
        "这里使用 schedule(dynamic, 1) 是因为不同像素的光线反射、折射次数不同，计算量存在差异。动态调度可以缓解负载不均，提高多核利用率。"
    )
    add_image(doc, assets.get("terminal_openmp.png"), "图 2  超算平台 OpenMP 版本运行截图：8 线程运行时间 9.72383 s，并检查了 PPM 文件头。", 6.4)

    doc.add_heading("6. CUDA 版本设计与超算提交", level=1)
    add_para(doc, "CUDA 版本将每个像素映射到一个 GPU 线程，使用 16×16 的线程块组织二维网格。递归 ray_color 被改写为迭代形式，以降低 GPU 栈压力。")
    add_code(
        doc,
        """
__global__ void render_kernel(float* framebuffer, int width, int height,
                              int samples, Camera camera,
                              curandState* rand_states, int scene_id,
                              const Sphere* spheres, int num_spheres,
                              const MaterialData* materials) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int j = blockIdx.y * blockDim.y + threadIdx.y;
    if (i >= width || j >= height) return;

    int idx = j * width + i;
    // 每个线程独立计算一个像素
}
""",
    )
    add_para(
        doc,
        "CUDA 版本使用 cudaMalloc 在显存中保存球体和材质数组，再将指针作为 kernel 参数传入。这样可以避免带构造函数结构体放入 __constant__ 变量时产生的动态初始化问题。"
    )
    add_code(
        doc,
        """
module load intel/cuda/12.1
nvcc -O3 -arch=sm_80 v3_cuda/main.cu -o v3_cuda/v3_cuda
sbatch scripts/submit_gpu_slurm.sh
squeue -u bjtu3
""",
    )
    add_para(
        doc,
        "实验过程中曾在登录节点直接运行 CUDA 程序并出现 CUDA driver version is insufficient for CUDA runtime version。该问题不是编译错误，而是登录节点通常不提供可用 GPU 运行环境。"
        "随后将程序提交到 gpu_4090 分区后，该问题消失，说明 CUDA 程序应在 GPU 计算节点上运行。"
    )

    doc.add_heading("7. 渲染结果与图片对比", level=1)
    add_para(
        doc,
        "超算平台生成了两张 400×300 的 PPM 渲染结果。为了便于插入报告，已将 PPM 转换为 JPG，并与 PNG 预览共同保存在 results/report_assets 目录。"
    )
    add_two_images(
        doc,
        assets.get("hpc_output_1.jpg"),
        assets.get("hpc_output_3.jpg"),
        "图 3(a)  超算输出 hpc_output_1.ppm 转 JPG",
        "图 3(b)  超算输出 hpc_output_3.ppm 转 JPG",
    )
    add_para(
        doc,
        "两张图片均能正确解析为 P3 格式 PPM，尺寸为 400×300。由于随机采样和随机场景生成存在差异，两次输出的局部颜色和小球位置不完全相同，但整体场景、材质和光线追踪效果一致。"
    )

    doc.add_heading("8. 扩展展示场景", level=1)
    add_para(
        doc,
        "为了让结果更接近图形渲染和游戏/科幻画面的展示需求，项目增加了程序化展示场景，包括黑洞吸积盘、城市追车和雪地赛道超跑。"
        "这些场景由程序生成，不依赖商业游戏资源或外部贴图。"
    )
    add_two_images(
        doc,
        assets.get("showcase_blackhole_preview.png"),
        assets.get("showcase_city_drive_preview.png"),
        "图 4(a)  程序化黑洞吸积盘预览",
        "图 4(b)  程序化城市追车预览",
    )
    add_image(doc, assets.get("showcase_snow_gt_preview.png"), "图 5  程序化雪地赛道超跑预览。", 4.8)

    doc.add_heading("9. 性能结果与分析", level=1)
    add_perf_table(doc)
    add_para(
        doc,
        "由表 1 可见，OpenMP 8 线程版本将运行时间从 39.1013 s 降低到 9.72383 s，加速比约为 4.02×。"
        "虽然低于理想线性加速 8×，但已经说明像素级并行对光线追踪任务具有明显效果。"
    )
    add_para(
        doc,
        "加速比未达到理想值的原因主要包括：场景初始化和文件输出仍存在串行部分；不同像素追踪深度不同导致负载不均；动态调度和随机数生成带来额外开销；多线程访问共享场景数据时会受到缓存和内存带宽影响。"
    )
    add_code(
        doc,
        """
Speedup = T_serial / T_parallel
        = 39.1013 / 9.72383
        ≈ 4.02

Efficiency(8 threads) = Speedup / 8 ≈ 50.3%
""",
    )

    doc.add_heading("10. 复现方法与提交文件说明", level=1)
    add_para(
        doc,
        "提交压缩包中包含原始串行代码、OpenMP 优化代码、CUDA 优化代码、运行说明、实验报告以及答辩 PPT PDF。助教可按以下命令复现小规模正确性测试。"
    )
    add_code(
        doc,
        """
g++ -O2 -std=c++17 v1_serial/main.cpp -o v1_serial/v1_serial
g++ -O2 -std=c++17 -fopenmp v2_openmp/main.cpp -o v2_openmp/v2_openmp
module load intel/cuda/12.1
nvcc -O3 -arch=sm_80 v3_cuda/main.cu -o v3_cuda/v3_cuda
OMP_NUM_THREADS=8 ./v2_openmp/v2_openmp --width 400 --height 300 --samples 64 --scene racing
sbatch scripts/submit_gpu_slurm.sh
""",
    )

    doc.add_heading("11. 遇到的问题与后续计划", level=1)
    add_bullets(
        doc,
        [
            "CUDA 登录节点运行限制：登录节点不能作为正式 GPU 运行环境，应通过 Slurm 提交到 GPU 分区。",
            "benchmark_results.csv 尚未生成：当前截图显示脚本化 benchmark 未完整跑完，后续应使用 scripts/run_benchmark.sh 统一采集数据。",
            "图像展示仍可提升：如果时间允许，可加入 OBJ 模型加载、三角形求交和 BVH 加速结构，提升车辆和城市场景的真实感。",
        ],
    )

    doc.add_heading("12. 结论", level=1)
    add_para(
        doc,
        "本实验完成了光线追踪渲染器的串行、OpenMP 和 CUDA 三版本实现。其中串行和 OpenMP 版本已在超算平台完成实测，"
        "OpenMP 8 线程相对串行版本获得约 4.02× 加速。CUDA 版本已完成编译和 GPU 队列提交流程，能够作为后续大规模渲染与性能测试的基础。"
    )
    add_para(
        doc,
        "总体来看，光线追踪具有明显的像素级并行特征，非常适合使用 OpenMP 和 CUDA 加速。本项目不仅验证了多核 CPU 并行的效果，也为后续 GPU 大规模并行实验和更复杂场景渲染奠定了基础。"
    )

    doc.save(OUT)


if __name__ == "__main__":
    build_doc()
    print(OUT)
