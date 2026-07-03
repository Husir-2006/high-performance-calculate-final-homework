#include <chrono>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include "camera.h"
#include "hittable.h"
#include "material.h"
#include "ray.h"
#include "sphere.h"
#include "utils.h"
#include "vec3.h"

// 默认渲染参数（本地测试用，超算上可通过命令行覆盖）
static int WIDTH = 400;
static int HEIGHT = 300;
static int SAMPLES = 64;
static const int MAX_DEPTH = 50;
static std::string SCENE = "classic";

Vec3 ray_color(const Ray& r, const HittableList& world,
               const std::vector<std::shared_ptr<Material>>& materials, int depth) {
    if (depth <= 0) return Vec3(0, 0, 0);

    HitRecord rec;
    if (world.hit(r, 0.001f, INF, rec)) {
        Ray scattered;
        Vec3 attenuation;
        if (materials[rec.mat_id]->scatter(r, rec, attenuation, scattered)) {
            return attenuation * ray_color(scattered, world, materials, depth - 1);
        }
        return Vec3(0, 0, 0);
    }

    Vec3 unit_direction = r.direction.normalize();
    float t = 0.5f * (unit_direction.y + 1.0f);
    return Vec3(1.0f, 1.0f, 1.0f) * (1.0f - t) + Vec3(0.5f, 0.7f, 1.0f) * t;
}

float smoothstep(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
    return t * t * (3.0f - 2.0f * t);
}

float fract(float x) {
    return x - std::floor(x);
}

float noise2(float x, float y) {
    return fract(std::sin(x * 12.9898f + y * 78.233f) * 43758.5453f);
}

Vec3 blackhole_color(float u, float v, float aspect_ratio) {
    float x = (u - 0.5f) * 2.0f * aspect_ratio;
    float y = (v - 0.5f) * 2.0f;
    float cx = 0.52f;
    float cy = 0.02f;
    float dx = x - cx;
    float dy = y - cy;
    float r = std::sqrt(dx * dx + dy * dy);
    float theta = std::atan2(dy, dx);

    float star = noise2(std::floor((x + 3.0f) * 420.0f), std::floor((y + 2.0f) * 420.0f));
    float star_field = star > 0.997f ? 0.35f * star : 0.0f;
    Vec3 color(star_field, star_field, star_field * 1.15f);

    float disk_axis = dy + 0.20f * dx;
    float disk_width = 0.045f + 0.09f / (1.0f + 2.8f * r);
    float disk = std::exp(-std::fabs(disk_axis) / disk_width);
    disk *= smoothstep(1.95f, 0.32f, r) * smoothstep(0.34f, 0.52f, r);

    float streaks = 0.55f + 0.45f * std::sin(theta * 34.0f + r * 95.0f);
    streaks *= 0.65f + 0.35f * noise2(theta * 11.0f, r * 37.0f);
    float doppler = 0.85f + 0.65f * smoothstep(-1.0f, 0.75f, -dx);
    Vec3 disk_color = Vec3(1.0f, 0.55f, 0.20f) * (disk * (0.6f + 1.4f * streaks) * doppler);

    float photon_ring = std::exp(-std::fabs(r - 0.43f) / 0.015f);
    float outer_ring = std::exp(-std::fabs(r - 0.54f) / 0.035f) * (0.5f + 0.5f * std::sin(theta * 18.0f));
    Vec3 ring_color = Vec3(1.0f, 0.86f, 0.66f) * (2.7f * photon_ring + 0.8f * outer_ring);

    float vertical_lens = std::exp(-std::fabs(dx) / 0.16f) * smoothstep(0.15f, 0.75f, std::fabs(dy));
    vertical_lens *= smoothstep(1.4f, 0.38f, r);
    Vec3 lens_color = Vec3(0.9f, 0.78f, 1.0f) * vertical_lens * 0.55f;

    float shadow = 1.0f - smoothstep(0.37f, 0.44f, r);
    float right_shadow = smoothstep(0.02f, 0.75f, dx) * std::exp(-std::fabs(dy) / 0.24f) * smoothstep(1.1f, 0.35f, r);

    float moon_dx = x + 0.55f;
    float moon_dy = y - 0.04f;
    float moon_r = std::sqrt(moon_dx * moon_dx + moon_dy * moon_dy);
    float moon = 1.0f - smoothstep(0.045f, 0.055f, moon_r);
    Vec3 moon_color = Vec3(0.025f, 0.023f, 0.022f) * moon;
    float moon_rim = std::exp(-std::fabs(moon_r - 0.052f) / 0.004f) * 0.25f;

    color += disk_color + ring_color + lens_color + Vec3(0.95f, 0.82f, 0.65f) * moon_rim + moon_color;
    color *= (1.0f - 0.98f * shadow) * (1.0f - 0.80f * right_shadow);
    color += ring_color * 0.35f;
    color.x = clamp(color.x, 0.0f, 6.0f);
    color.y = clamp(color.y, 0.0f, 6.0f);
    color.z = clamp(color.z, 0.0f, 6.0f);
    return color;
}

float ellipse_mask(float x, float y, float cx, float cy, float rx, float ry, float feather) {
    float qx = (x - cx) / rx;
    float qy = (y - cy) / ry;
    float d = std::sqrt(qx * qx + qy * qy);
    return 1.0f - smoothstep(1.0f - feather, 1.0f + feather, d);
}

float box_mask(float x, float y, float cx, float cy, float hx, float hy, float feather) {
    float dx = std::fabs(x - cx) - hx;
    float dy = std::fabs(y - cy) - hy;
    float d = std::fmax(dx, dy);
    return 1.0f - smoothstep(-feather, feather, d);
}

Vec3 mix_color(const Vec3& a, const Vec3& b, float t) {
    return a * (1.0f - t) + b * t;
}

Vec3 car_cinematic_color(float u, float v, float aspect_ratio, bool snow_scene) {
    float x = (u - 0.5f) * 2.0f * aspect_ratio;
    float y = (v - 0.5f) * 2.0f;

    Vec3 sky = snow_scene ? Vec3(0.55f, 0.72f, 0.92f) : Vec3(1.0f, 0.84f, 0.55f);
    Vec3 horizon = snow_scene ? Vec3(0.92f, 0.96f, 1.0f) : Vec3(1.0f, 0.93f, 0.76f);
    Vec3 road = snow_scene ? Vec3(0.54f, 0.50f, 0.47f) : Vec3(0.43f, 0.34f, 0.24f);
    Vec3 color = mix_color(road, mix_color(horizon, sky, smoothstep(0.1f, 0.9f, y)), smoothstep(-0.78f, 0.05f, y));

    float road_perspective = smoothstep(-0.88f, 0.08f, y);
    float lane = std::exp(-std::fabs(x + 0.04f) / (0.012f + 0.03f * road_perspective));
    color += Vec3(0.95f, 0.86f, 0.66f) * lane * smoothstep(-0.85f, -0.05f, y) * 0.75f;

    for (int i = 0; i < 34; i++) {
        float fi = static_cast<float>(i);
        float px = -aspect_ratio + fract(fi * 0.371f) * aspect_ratio * 2.0f;
        float py = -0.12f + fract(fi * 0.193f) * 0.72f;
        float trunk = box_mask(x, y, px, py - 0.14f, 0.010f, 0.17f, 0.015f);
        float crown = ellipse_mask(x, y, px, py + 0.04f, 0.14f, 0.24f, 0.45f);
        Vec3 leaf = snow_scene ? Vec3(0.72f, 0.80f, 0.88f) : Vec3(0.95f, 0.46f, 0.06f);
        color = mix_color(color, leaf, crown * (0.35f + 0.35f * noise2(fi, y * 9.0f)));
        color = mix_color(color, Vec3(0.12f, 0.08f, 0.04f), trunk * 0.55f);
    }

    if (!snow_scene) {
        for (int i = 0; i < 8; i++) {
            float bx = -1.6f + i * 0.45f;
            float bh = 0.35f + 0.28f * noise2(i * 3.0f, 1.0f);
            float b = box_mask(x, y, bx, 0.22f + bh * 0.35f, 0.18f, bh, 0.015f);
            float windows = 0.55f + 0.45f * std::sin((x - bx) * 80.0f) * std::sin(y * 55.0f);
            color = mix_color(color, Vec3(0.38f, 0.35f, 0.31f) + Vec3(0.12f, 0.14f, 0.16f) * windows, b * 0.65f);
        }
    }

    for (int i = 0; i < 28; i++) {
        float streak_y = -0.82f + i * 0.035f;
        float streak = std::exp(-std::fabs(y - streak_y) / 0.006f) * smoothstep(-1.7f, 0.9f, x);
        color += (snow_scene ? Vec3(0.9f, 0.88f, 0.82f) : Vec3(0.9f, 0.66f, 0.32f)) * streak * 0.08f;
    }

    float car_x = snow_scene ? 0.10f : 0.56f;
    float car_y = -0.43f;
    float body = ellipse_mask(x, y, car_x, car_y, snow_scene ? 0.98f : 0.72f, 0.26f, 0.18f);
    body += box_mask(x, y, car_x, car_y - 0.02f, snow_scene ? 0.92f : 0.66f, 0.16f, 0.04f);
    body = clamp(body, 0.0f, 1.0f);
    Vec3 paint = snow_scene ? Vec3(0.92f, 0.95f, 0.98f) : Vec3(0.78f, 0.86f, 0.84f);
    Vec3 paint_shadow = snow_scene ? Vec3(0.18f, 0.20f, 0.22f) : Vec3(0.23f, 0.24f, 0.22f);
    float highlight = smoothstep(-0.15f, 0.65f, y - car_y) * (0.5f + 0.5f * std::sin((x - car_x) * 18.0f));
    color = mix_color(color, mix_color(paint_shadow, paint, 0.65f + 0.35f * highlight), body);

    float cabin = box_mask(x, y, car_x - 0.08f, car_y + 0.22f, snow_scene ? 0.48f : 0.34f, 0.14f, 0.05f);
    color = mix_color(color, snow_scene ? Vec3(0.18f, 0.45f, 0.68f) : Vec3(0.18f, 0.34f, 0.40f), cabin * 0.75f);

    float grille = box_mask(x, y, car_x - (snow_scene ? 0.48f : 0.28f), car_y - 0.10f, 0.22f, 0.08f, 0.02f);
    color = mix_color(color, Vec3(0.015f, 0.015f, 0.018f), grille * 0.9f);

    float wheel1 = ellipse_mask(x, y, car_x - (snow_scene ? 0.54f : 0.38f), car_y - 0.20f, 0.16f, 0.21f, 0.08f);
    float wheel2 = ellipse_mask(x, y, car_x + (snow_scene ? 0.56f : 0.34f), car_y - 0.20f, 0.16f, 0.21f, 0.08f);
    color = mix_color(color, Vec3(0.01f, 0.01f, 0.012f), clamp(wheel1 + wheel2, 0.0f, 1.0f));
    color += Vec3(0.7f, 0.72f, 0.75f) * (ellipse_mask(x, y, car_x - 0.38f, car_y - 0.20f, 0.055f, 0.075f, 0.08f) +
                                           ellipse_mask(x, y, car_x + 0.34f, car_y - 0.20f, 0.055f, 0.075f, 0.08f)) * 0.5f;

    float headlight = ellipse_mask(x, y, car_x - (snow_scene ? 0.72f : 0.48f), car_y + 0.01f, 0.08f, 0.035f, 0.08f);
    color += (snow_scene ? Vec3(0.65f, 0.9f, 1.2f) : Vec3(1.0f, 0.85f, 0.45f)) * headlight * 1.2f;

    if (snow_scene) {
        float wing = box_mask(x, y, car_x + 0.72f, car_y + 0.34f, 0.34f, 0.035f, 0.015f);
        color = mix_color(color, Vec3(0.02f, 0.025f, 0.03f), wing);
    }

    float vignette = smoothstep(1.45f, 0.25f, std::sqrt(x * x * 0.35f + y * y));
    color *= 0.62f + 0.38f * vignette;
    return color;
}

Vec3 procedural_scene_color(const std::string& scene_name, float u, float v, float aspect_ratio) {
    if (scene_name == "blackhole") return blackhole_color(u, v, aspect_ratio);
    if (scene_name == "city_drive") return car_cinematic_color(u, v, aspect_ratio, false);
    if (scene_name == "snow_gt") return car_cinematic_color(u, v, aspect_ratio, true);
    return Vec3(0, 0, 0);
}

bool is_procedural_scene(const std::string& scene_name) {
    return scene_name == "blackhole" || scene_name == "city_drive" || scene_name == "snow_gt";
}

void build_scene(HittableList& world, std::vector<std::shared_ptr<Material>>& materials,
                 const std::string& scene_name) {
    auto add_material = [&](std::shared_ptr<Material> m) -> int {
        materials.push_back(m);
        return static_cast<int>(materials.size()) - 1;
    };

    if (scene_name == "racing") {
        int asphalt = add_material(std::make_shared<Lambertian>(Vec3(0.08f, 0.085f, 0.09f)));
        int grass = add_material(std::make_shared<Lambertian>(Vec3(0.05f, 0.24f, 0.08f)));
        int white = add_material(std::make_shared<Lambertian>(Vec3(0.9f, 0.9f, 0.82f)));
        int red = add_material(std::make_shared<Lambertian>(Vec3(0.85f, 0.05f, 0.04f)));
        int blue_metal = add_material(std::make_shared<Metal>(Vec3(0.08f, 0.20f, 0.95f), 0.08f));
        int black = add_material(std::make_shared<Lambertian>(Vec3(0.01f, 0.01f, 0.012f)));
        int chrome = add_material(std::make_shared<Metal>(Vec3(0.82f, 0.84f, 0.86f), 0.02f));
        int glass = add_material(std::make_shared<Dielectric>(1.5f));
        int gold = add_material(std::make_shared<Metal>(Vec3(1.0f, 0.72f, 0.18f), 0.1f));

        world.add(std::make_shared<Sphere>(Vec3(0, -1000.0f, 0), 1000.0f, asphalt));
        world.add(std::make_shared<Sphere>(Vec3(-8, -1000.45f, 0), 1000.0f, grass));
        world.add(std::make_shared<Sphere>(Vec3(8, -1000.45f, 0), 1000.0f, grass));

        for (int z = -12; z <= 8; z += 2) {
            world.add(std::make_shared<Sphere>(Vec3(-3.1f, 0.12f, z), 0.18f, (z % 4 == 0) ? red : white));
            world.add(std::make_shared<Sphere>(Vec3(3.1f, 0.12f, z), 0.18f, (z % 4 == 0) ? white : red));
            world.add(std::make_shared<Sphere>(Vec3(0.0f, 0.025f, z + 0.4f), 0.08f, white));
        }

        // 原创赛车展示：用球体组合表现车身、座舱、轮胎和高光反射。
        world.add(std::make_shared<Sphere>(Vec3(0, 0.72f, -1.5f), 0.95f, blue_metal));
        world.add(std::make_shared<Sphere>(Vec3(-0.9f, 0.58f, -1.5f), 0.55f, blue_metal));
        world.add(std::make_shared<Sphere>(Vec3(0.9f, 0.58f, -1.5f), 0.55f, blue_metal));
        world.add(std::make_shared<Sphere>(Vec3(0, 1.35f, -1.55f), 0.48f, glass));
        world.add(std::make_shared<Sphere>(Vec3(-0.85f, 0.32f, -0.85f), 0.34f, black));
        world.add(std::make_shared<Sphere>(Vec3(0.85f, 0.32f, -0.85f), 0.34f, black));
        world.add(std::make_shared<Sphere>(Vec3(-0.85f, 0.32f, -2.2f), 0.34f, black));
        world.add(std::make_shared<Sphere>(Vec3(0.85f, 0.32f, -2.2f), 0.34f, black));
        world.add(std::make_shared<Sphere>(Vec3(-0.85f, 0.32f, -0.85f), 0.16f, chrome));
        world.add(std::make_shared<Sphere>(Vec3(0.85f, 0.32f, -0.85f), 0.16f, chrome));
        world.add(std::make_shared<Sphere>(Vec3(-0.85f, 0.32f, -2.2f), 0.16f, chrome));
        world.add(std::make_shared<Sphere>(Vec3(0.85f, 0.32f, -2.2f), 0.16f, chrome));

        for (int i = 0; i < 9; i++) {
            float x = -4.0f + i;
            world.add(std::make_shared<Sphere>(Vec3(x, 0.25f, -6.5f), 0.22f, gold));
        }
        return;
    }

    if (scene_name == "neon") {
        int floor = add_material(std::make_shared<Metal>(Vec3(0.20f, 0.21f, 0.24f), 0.18f));
        int cyan = add_material(std::make_shared<Metal>(Vec3(0.05f, 0.85f, 1.0f), 0.03f));
        int magenta = add_material(std::make_shared<Metal>(Vec3(1.0f, 0.08f, 0.75f), 0.05f));
        int black = add_material(std::make_shared<Lambertian>(Vec3(0.01f, 0.01f, 0.015f)));
        int glass = add_material(std::make_shared<Dielectric>(1.45f));
        int white = add_material(std::make_shared<Lambertian>(Vec3(0.8f, 0.82f, 0.9f)));

        world.add(std::make_shared<Sphere>(Vec3(0, -1000.55f, 0), 1000.0f, floor));
        world.add(std::make_shared<Sphere>(Vec3(0, 1.1f, -1.5f), 1.0f, glass));
        world.add(std::make_shared<Sphere>(Vec3(-1.45f, 0.72f, -1.2f), 0.62f, cyan));
        world.add(std::make_shared<Sphere>(Vec3(1.45f, 0.72f, -1.2f), 0.62f, magenta));
        world.add(std::make_shared<Sphere>(Vec3(0, 0.35f, 0.35f), 0.45f, black));

        for (int i = 0; i < 12; i++) {
            float x = -5.5f + i;
            int mat = (i % 2 == 0) ? cyan : magenta;
            world.add(std::make_shared<Sphere>(Vec3(x, 0.15f, -4.5f), 0.18f, mat));
            world.add(std::make_shared<Sphere>(Vec3(x, 2.0f, -5.0f), 0.2f, white));
        }
        return;
    }

    int ground_mat = add_material(std::make_shared<Lambertian>(Vec3(0.5f, 0.5f, 0.5f)));
    world.add(std::make_shared<Sphere>(Vec3(0, -1000, 0), 1000.0f, ground_mat));

    // 随机小球
    for (int a = -11; a < 11; a++) {
        for (int b = -11; b < 11; b++) {
            float choose_mat = random_float();
            Vec3 center(a + 0.9f * random_float(), 0.2f, b + 0.9f * random_float());

            if ((center - Vec3(4, 0.2f, 0)).length() > 0.9f) {
                int mat_id;
                if (choose_mat < 0.8f) {
                    Vec3 albedo = random_vec3() * random_vec3();
                    mat_id = add_material(std::make_shared<Lambertian>(albedo));
                } else if (choose_mat < 0.95f) {
                    Vec3 albedo = random_vec3(0.5f, 1.0f);
                    float fuzz = random_float(0.0f, 0.5f);
                    mat_id = add_material(std::make_shared<Metal>(albedo, fuzz));
                } else {
                    mat_id = add_material(std::make_shared<Dielectric>(1.5f));
                }
                world.add(std::make_shared<Sphere>(center, 0.2f, mat_id));
            }
        }
    }

    // 3个主球
    int mat_glass = add_material(std::make_shared<Dielectric>(1.5f));
    world.add(std::make_shared<Sphere>(Vec3(0, 1, 0), 1.0f, mat_glass));

    int mat_diffuse = add_material(std::make_shared<Lambertian>(Vec3(0.4f, 0.2f, 0.1f)));
    world.add(std::make_shared<Sphere>(Vec3(-4, 1, 0), 1.0f, mat_diffuse));

    int mat_metal = add_material(std::make_shared<Metal>(Vec3(0.7f, 0.6f, 0.5f), 0.0f));
    world.add(std::make_shared<Sphere>(Vec3(4, 1, 0), 1.0f, mat_metal));
}

void write_pixel(std::ostream& out, Vec3 color, int samples) {
    float scale = 1.0f / samples;
    float r = std::sqrt(color.x * scale);
    float g = std::sqrt(color.y * scale);
    float b = std::sqrt(color.z * scale);

    int ir = static_cast<int>(256 * clamp(r, 0.0f, 0.999f));
    int ig = static_cast<int>(256 * clamp(g, 0.0f, 0.999f));
    int ib = static_cast<int>(256 * clamp(b, 0.0f, 0.999f));

    out << ir << ' ' << ig << ' ' << ib << '\n';
}

int main(int argc, char** argv) {
    // 命令行可选参数：--width W --height H --samples S
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--width" && i + 1 < argc) WIDTH = std::atoi(argv[++i]);
        else if (arg == "--height" && i + 1 < argc) HEIGHT = std::atoi(argv[++i]);
        else if (arg == "--samples" && i + 1 < argc) SAMPLES = std::atoi(argv[++i]);
        else if (arg == "--scene" && i + 1 < argc) SCENE = argv[++i];
    }

    HittableList world;
    std::vector<std::shared_ptr<Material>> materials;
    build_scene(world, materials, SCENE);

    Vec3 lookfrom = (SCENE == "racing") ? Vec3(5.5f, 2.2f, 4.6f) :
                    (SCENE == "neon") ? Vec3(4.2f, 2.0f, 4.2f) : Vec3(13, 2, 3);
    Vec3 lookat = (SCENE == "classic") ? Vec3(0, 0, 0) : Vec3(0, 0.65f, -1.6f);
    Vec3 vup(0, 1, 0);
    float dist_to_focus = 10.0f;
    float aperture = 0.1f;
    float aspect_ratio = static_cast<float>(WIDTH) / HEIGHT;
    Camera cam(lookfrom, lookat, vup, 20.0f, aspect_ratio, aperture, dist_to_focus);

    std::ofstream out("output.ppm");
    out << "P3\n" << WIDTH << ' ' << HEIGHT << "\n255\n";

    auto start = std::chrono::high_resolution_clock::now();

    for (int j = HEIGHT - 1; j >= 0; j--) {
        std::cerr << "\rRendering scanline " << (HEIGHT - j) << '/' << HEIGHT << std::flush;
        for (int i = 0; i < WIDTH; i++) {
            Vec3 color(0, 0, 0);
            for (int s = 0; s < SAMPLES; s++) {
                float u = (i + random_float()) / (WIDTH - 1);
                float v = (j + random_float()) / (HEIGHT - 1);
                if (is_procedural_scene(SCENE)) {
                    color += procedural_scene_color(SCENE, u, v, aspect_ratio);
                } else {
                    Ray r = cam.get_ray(u, v);
                    color += ray_color(r, world, materials, MAX_DEPTH);
                }
            }
            write_pixel(out, color, SAMPLES);
        }
    }

    auto end = std::chrono::high_resolution_clock::now();
    double elapsed = std::chrono::duration<double>(end - start).count();

    std::cerr << "\nDone.\n";
    std::cerr << "Render time: " << elapsed << " s\n";
    std::cout << "Render time: " << elapsed << " s" << std::endl;

    out.close();
    return 0;
}
