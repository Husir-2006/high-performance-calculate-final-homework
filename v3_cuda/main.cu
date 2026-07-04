#include <cuda_runtime.h>
#include <curand_kernel.h>

#include <chrono>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#include "camera.cuh"
#include "material.cuh"
#include "ray.cuh"
#include "sphere.cuh"
#include "vec3.cuh"

static int WIDTH = 400;
static int HEIGHT = 300;
static int SAMPLES = 64;
static std::string SCENE = "classic";
static const int MAX_DEPTH = 50;
static const int MAX_SPHERES = 512;
static const int MAX_MATERIALS = 512;

#define CUDA_CHECK(call) do { \
    cudaError_t err = call; \
    if (err != cudaSuccess) { \
        std::cerr << "CUDA error: " << cudaGetErrorString(err) \
                  << " at " << __FILE__ << ":" << __LINE__ << std::endl; \
        std::exit(1); \
    } \
} while (0)

struct HostRng {
    unsigned int state;

    explicit HostRng(unsigned int seed) : state(seed) {}

    float next() {
        state = 1664525u * state + 1013904223u;
        return static_cast<float>(state & 0x00ffffffu) / static_cast<float>(0x01000000u);
    }

    float next(float min_value, float max_value) {
        return min_value + (max_value - min_value) * next();
    }

    Vec3 vec3() { return Vec3(next(), next(), next()); }
    Vec3 vec3(float min_value, float max_value) {
        return Vec3(next(min_value, max_value), next(min_value, max_value), next(min_value, max_value));
    }
};

static int add_material(std::vector<MaterialData>& materials, MaterialData material) {
    if (static_cast<int>(materials.size()) >= MAX_MATERIALS) {
        std::cerr << "Too many materials; increase MAX_MATERIALS." << std::endl;
        std::exit(1);
    }
    materials.push_back(material);
    return static_cast<int>(materials.size()) - 1;
}

static void add_sphere(std::vector<Sphere>& spheres, const Sphere& sphere) {
    if (static_cast<int>(spheres.size()) >= MAX_SPHERES) {
        std::cerr << "Too many spheres; increase MAX_SPHERES." << std::endl;
        std::exit(1);
    }
    spheres.push_back(sphere);
}

static MaterialData make_lambertian(const Vec3& albedo) {
    return MaterialData{MAT_LAMBERTIAN, albedo, 0.0f, 1.0f};
}

static MaterialData make_metal(const Vec3& albedo, float fuzz) {
    return MaterialData{MAT_METAL, albedo, fuzz < 1.0f ? fuzz : 1.0f, 1.0f};
}

static MaterialData make_dielectric(float ir) {
    return MaterialData{MAT_DIELECTRIC, Vec3(1.0f, 1.0f, 1.0f), 0.0f, ir};
}

static void build_scene(std::vector<Sphere>& spheres, std::vector<MaterialData>& materials,
                        const std::string& scene_name) {
    HostRng rng(20260616u);

    if (scene_name == "racing") {
        int asphalt = add_material(materials, make_lambertian(Vec3(0.08f, 0.085f, 0.09f)));
        int grass = add_material(materials, make_lambertian(Vec3(0.05f, 0.24f, 0.08f)));
        int white = add_material(materials, make_lambertian(Vec3(0.9f, 0.9f, 0.82f)));
        int red = add_material(materials, make_lambertian(Vec3(0.85f, 0.05f, 0.04f)));
        int blue_metal = add_material(materials, make_metal(Vec3(0.08f, 0.20f, 0.95f), 0.08f));
        int black = add_material(materials, make_lambertian(Vec3(0.01f, 0.01f, 0.012f)));
        int chrome = add_material(materials, make_metal(Vec3(0.82f, 0.84f, 0.86f), 0.02f));
        int glass = add_material(materials, make_dielectric(1.5f));
        int gold = add_material(materials, make_metal(Vec3(1.0f, 0.72f, 0.18f), 0.1f));

        add_sphere(spheres, Sphere(Vec3(0, -1000.0f, 0), 1000.0f, asphalt));
        add_sphere(spheres, Sphere(Vec3(-8, -1000.45f, 0), 1000.0f, grass));
        add_sphere(spheres, Sphere(Vec3(8, -1000.45f, 0), 1000.0f, grass));

        for (int z = -12; z <= 8; z += 2) {
            add_sphere(spheres, Sphere(Vec3(-3.1f, 0.12f, z), 0.18f, (z % 4 == 0) ? red : white));
            add_sphere(spheres, Sphere(Vec3(3.1f, 0.12f, z), 0.18f, (z % 4 == 0) ? white : red));
            add_sphere(spheres, Sphere(Vec3(0.0f, 0.025f, z + 0.4f), 0.08f, white));
        }

        add_sphere(spheres, Sphere(Vec3(0, 0.72f, -1.5f), 0.95f, blue_metal));
        add_sphere(spheres, Sphere(Vec3(-0.9f, 0.58f, -1.5f), 0.55f, blue_metal));
        add_sphere(spheres, Sphere(Vec3(0.9f, 0.58f, -1.5f), 0.55f, blue_metal));
        add_sphere(spheres, Sphere(Vec3(0, 1.35f, -1.55f), 0.48f, glass));
        add_sphere(spheres, Sphere(Vec3(-0.85f, 0.32f, -0.85f), 0.34f, black));
        add_sphere(spheres, Sphere(Vec3(0.85f, 0.32f, -0.85f), 0.34f, black));
        add_sphere(spheres, Sphere(Vec3(-0.85f, 0.32f, -2.2f), 0.34f, black));
        add_sphere(spheres, Sphere(Vec3(0.85f, 0.32f, -2.2f), 0.34f, black));
        add_sphere(spheres, Sphere(Vec3(-0.85f, 0.32f, -0.85f), 0.16f, chrome));
        add_sphere(spheres, Sphere(Vec3(0.85f, 0.32f, -0.85f), 0.16f, chrome));
        add_sphere(spheres, Sphere(Vec3(-0.85f, 0.32f, -2.2f), 0.16f, chrome));
        add_sphere(spheres, Sphere(Vec3(0.85f, 0.32f, -2.2f), 0.16f, chrome));

        for (int i = 0; i < 9; i++) {
            float x = -4.0f + i;
            add_sphere(spheres, Sphere(Vec3(x, 0.25f, -6.5f), 0.22f, gold));
        }
        return;
    }

    if (scene_name == "neon") {
        int floor = add_material(materials, make_metal(Vec3(0.20f, 0.21f, 0.24f), 0.18f));
        int cyan = add_material(materials, make_metal(Vec3(0.05f, 0.85f, 1.0f), 0.03f));
        int magenta = add_material(materials, make_metal(Vec3(1.0f, 0.08f, 0.75f), 0.05f));
        int black = add_material(materials, make_lambertian(Vec3(0.01f, 0.01f, 0.015f)));
        int glass = add_material(materials, make_dielectric(1.45f));
        int white = add_material(materials, make_lambertian(Vec3(0.8f, 0.82f, 0.9f)));

        add_sphere(spheres, Sphere(Vec3(0, -1000.55f, 0), 1000.0f, floor));
        add_sphere(spheres, Sphere(Vec3(0, 1.1f, -1.5f), 1.0f, glass));
        add_sphere(spheres, Sphere(Vec3(-1.45f, 0.72f, -1.2f), 0.62f, cyan));
        add_sphere(spheres, Sphere(Vec3(1.45f, 0.72f, -1.2f), 0.62f, magenta));
        add_sphere(spheres, Sphere(Vec3(0, 0.35f, 0.35f), 0.45f, black));

        for (int i = 0; i < 12; i++) {
            float x = -5.5f + i;
            int mat = (i % 2 == 0) ? cyan : magenta;
            add_sphere(spheres, Sphere(Vec3(x, 0.15f, -4.5f), 0.18f, mat));
            add_sphere(spheres, Sphere(Vec3(x, 2.0f, -5.0f), 0.2f, white));
        }
        return;
    }

    int ground_mat = add_material(materials, make_lambertian(Vec3(0.5f, 0.5f, 0.5f)));
    add_sphere(spheres, Sphere(Vec3(0, -1000, 0), 1000.0f, ground_mat));

    for (int a = -11; a < 11; a++) {
        for (int b = -11; b < 11; b++) {
            float choose_mat = rng.next();
            Vec3 center(a + 0.9f * rng.next(), 0.2f, b + 0.9f * rng.next());

            if ((center - Vec3(4, 0.2f, 0)).length() > 0.9f) {
                int mat_id;
                if (choose_mat < 0.8f) {
                    Vec3 albedo = rng.vec3() * rng.vec3();
                    mat_id = add_material(materials, make_lambertian(albedo));
                } else if (choose_mat < 0.95f) {
                    Vec3 albedo = rng.vec3(0.5f, 1.0f);
                    float fuzz = rng.next(0.0f, 0.5f);
                    mat_id = add_material(materials, make_metal(albedo, fuzz));
                } else {
                    mat_id = add_material(materials, make_dielectric(1.5f));
                }
                add_sphere(spheres, Sphere(center, 0.2f, mat_id));
            }
        }
    }

    int mat_glass = add_material(materials, make_dielectric(1.5f));
    add_sphere(spheres, Sphere(Vec3(0, 1, 0), 1.0f, mat_glass));

    int mat_diffuse = add_material(materials, make_lambertian(Vec3(0.4f, 0.2f, 0.1f)));
    add_sphere(spheres, Sphere(Vec3(-4, 1, 0), 1.0f, mat_diffuse));

    int mat_metal = add_material(materials, make_metal(Vec3(0.7f, 0.6f, 0.5f), 0.0f));
    add_sphere(spheres, Sphere(Vec3(4, 1, 0), 1.0f, mat_metal));
}

__device__ bool hit_world(const Ray& r, float t_min, float t_max, HitRecord& rec,
                          const Sphere* spheres, int num_spheres) {
    HitRecord temp_rec;
    bool hit_anything = false;
    float closest_so_far = t_max;

    for (int i = 0; i < num_spheres; i++) {
        if (spheres[i].hit(r, t_min, closest_so_far, temp_rec)) {
            hit_anything = true;
            closest_so_far = temp_rec.t;
            rec = temp_rec;
        }
    }
    return hit_anything;
}

__device__ Vec3 background_color(const Ray& r) {
    Vec3 unit_direction = r.direction.normalize();
    float t = 0.5f * (unit_direction.y + 1.0f);
    return Vec3(1.0f, 1.0f, 1.0f) * (1.0f - t) + Vec3(0.5f, 0.7f, 1.0f) * t;
}

__device__ float smoothstep_device(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
    return t * t * (3.0f - 2.0f * t);
}

__device__ float fract_device(float x) {
    return x - floorf(x);
}

__device__ float noise2_device(float x, float y) {
    return fract_device(sinf(x * 12.9898f + y * 78.233f) * 43758.5453f);
}

__device__ Vec3 blackhole_color(float u, float v, float aspect_ratio) {
    float x = (u - 0.5f) * 2.0f * aspect_ratio;
    float y = (v - 0.5f) * 2.0f;
    float cx = 0.52f;
    float cy = 0.02f;
    float dx = x - cx;
    float dy = y - cy;
    float r = sqrtf(dx * dx + dy * dy);
    float theta = atan2f(dy, dx);

    float star = noise2_device(floorf((x + 3.0f) * 420.0f), floorf((y + 2.0f) * 420.0f));
    float star_field = star > 0.997f ? 0.35f * star : 0.0f;
    Vec3 color(star_field, star_field, star_field * 1.15f);

    float disk_axis = dy + 0.20f * dx;
    float disk_width = 0.045f + 0.09f / (1.0f + 2.8f * r);
    float disk = expf(-fabsf(disk_axis) / disk_width);
    disk *= smoothstep_device(1.95f, 0.32f, r) * smoothstep_device(0.34f, 0.52f, r);

    float streaks = 0.55f + 0.45f * sinf(theta * 34.0f + r * 95.0f);
    streaks *= 0.65f + 0.35f * noise2_device(theta * 11.0f, r * 37.0f);
    float doppler = 0.85f + 0.65f * smoothstep_device(-1.0f, 0.75f, -dx);
    Vec3 disk_color = Vec3(1.0f, 0.55f, 0.20f) * (disk * (0.6f + 1.4f * streaks) * doppler);

    float photon_ring = expf(-fabsf(r - 0.43f) / 0.015f);
    float outer_ring = expf(-fabsf(r - 0.54f) / 0.035f) * (0.5f + 0.5f * sinf(theta * 18.0f));
    Vec3 ring_color = Vec3(1.0f, 0.86f, 0.66f) * (2.7f * photon_ring + 0.8f * outer_ring);

    float vertical_lens = expf(-fabsf(dx) / 0.16f) * smoothstep_device(0.15f, 0.75f, fabsf(dy));
    vertical_lens *= smoothstep_device(1.4f, 0.38f, r);
    Vec3 lens_color = Vec3(0.9f, 0.78f, 1.0f) * vertical_lens * 0.55f;

    float shadow = 1.0f - smoothstep_device(0.37f, 0.44f, r);
    float right_shadow = smoothstep_device(0.02f, 0.75f, dx) * expf(-fabsf(dy) / 0.24f) * smoothstep_device(1.1f, 0.35f, r);

    float moon_dx = x + 0.55f;
    float moon_dy = y - 0.04f;
    float moon_r = sqrtf(moon_dx * moon_dx + moon_dy * moon_dy);
    float moon = 1.0f - smoothstep_device(0.045f, 0.055f, moon_r);
    Vec3 moon_color = Vec3(0.025f, 0.023f, 0.022f) * moon;
    float moon_rim = expf(-fabsf(moon_r - 0.052f) / 0.004f) * 0.25f;

    color += disk_color + ring_color + lens_color + Vec3(0.95f, 0.82f, 0.65f) * moon_rim + moon_color;
    color =color* (1.0f - 0.98f * shadow) * (1.0f - 0.80f * right_shadow);
    color += ring_color * 0.35f;
    color.x = clamp(color.x, 0.0f, 6.0f);
    color.y = clamp(color.y, 0.0f, 6.0f);
    color.z = clamp(color.z, 0.0f, 6.0f);
    return color;
}

__device__ float ellipse_mask_device(float x, float y, float cx, float cy, float rx, float ry, float feather) {
    float qx = (x - cx) / rx;
    float qy = (y - cy) / ry;
    float d = sqrtf(qx * qx + qy * qy);
    return 1.0f - smoothstep_device(1.0f - feather, 1.0f + feather, d);
}

__device__ float box_mask_device(float x, float y, float cx, float cy, float hx, float hy, float feather) {
    float dx = fabsf(x - cx) - hx;
    float dy = fabsf(y - cy) - hy;
    float d = fmaxf(dx, dy);
    return 1.0f - smoothstep_device(-feather, feather, d);
}

__device__ Vec3 mix_color_device(const Vec3& a, const Vec3& b, float t) {
    return a * (1.0f - t) + b * t;
}

__device__ Vec3 car_cinematic_color(float u, float v, float aspect_ratio, bool snow_scene) {
    float x = (u - 0.5f) * 2.0f * aspect_ratio;
    float y = (v - 0.5f) * 2.0f;

    Vec3 sky = snow_scene ? Vec3(0.55f, 0.72f, 0.92f) : Vec3(1.0f, 0.84f, 0.55f);
    Vec3 horizon = snow_scene ? Vec3(0.92f, 0.96f, 1.0f) : Vec3(1.0f, 0.93f, 0.76f);
    Vec3 road = snow_scene ? Vec3(0.54f, 0.50f, 0.47f) : Vec3(0.43f, 0.34f, 0.24f);
    Vec3 color = mix_color_device(road, mix_color_device(horizon, sky, smoothstep_device(0.1f, 0.9f, y)), smoothstep_device(-0.78f, 0.05f, y));

    float road_perspective = smoothstep_device(-0.88f, 0.08f, y);
    float lane = expf(-fabsf(x + 0.04f) / (0.012f + 0.03f * road_perspective));
    color += Vec3(0.95f, 0.86f, 0.66f) * lane * smoothstep_device(-0.85f, -0.05f, y) * 0.75f;

    for (int i = 0; i < 34; i++) {
        float fi = static_cast<float>(i);
        float px = -aspect_ratio + fract_device(fi * 0.371f) * aspect_ratio * 2.0f;
        float py = -0.12f + fract_device(fi * 0.193f) * 0.72f;
        float trunk = box_mask_device(x, y, px, py - 0.14f, 0.010f, 0.17f, 0.015f);
        float crown = ellipse_mask_device(x, y, px, py + 0.04f, 0.14f, 0.24f, 0.45f);
        Vec3 leaf = snow_scene ? Vec3(0.72f, 0.80f, 0.88f) : Vec3(0.95f, 0.46f, 0.06f);
        color = mix_color_device(color, leaf, crown * (0.35f + 0.35f * noise2_device(fi, y * 9.0f)));
        color = mix_color_device(color, Vec3(0.12f, 0.08f, 0.04f), trunk * 0.55f);
    }

    if (!snow_scene) {
        for (int i = 0; i < 8; i++) {
            float bx = -1.6f + i * 0.45f;
            float bh = 0.35f + 0.28f * noise2_device(i * 3.0f, 1.0f);
            float b = box_mask_device(x, y, bx, 0.22f + bh * 0.35f, 0.18f, bh, 0.015f);
            float windows = 0.55f + 0.45f * sinf((x - bx) * 80.0f) * sinf(y * 55.0f);
            color = mix_color_device(color, Vec3(0.38f, 0.35f, 0.31f) + Vec3(0.12f, 0.14f, 0.16f) * windows, b * 0.65f);
        }
    }

    for (int i = 0; i < 28; i++) {
        float streak_y = -0.82f + i * 0.035f;
        float streak = expf(-fabsf(y - streak_y) / 0.006f) * smoothstep_device(-1.7f, 0.9f, x);
        color += (snow_scene ? Vec3(0.9f, 0.88f, 0.82f) : Vec3(0.9f, 0.66f, 0.32f)) * streak * 0.08f;
    }

    float car_x = snow_scene ? 0.10f : 0.56f;
    float car_y = -0.43f;
    float body = ellipse_mask_device(x, y, car_x, car_y, snow_scene ? 0.98f : 0.72f, 0.26f, 0.18f);
    body += box_mask_device(x, y, car_x, car_y - 0.02f, snow_scene ? 0.92f : 0.66f, 0.16f, 0.04f);
    body = clamp(body, 0.0f, 1.0f);
    Vec3 paint = snow_scene ? Vec3(0.92f, 0.95f, 0.98f) : Vec3(0.78f, 0.86f, 0.84f);
    Vec3 paint_shadow = snow_scene ? Vec3(0.18f, 0.20f, 0.22f) : Vec3(0.23f, 0.24f, 0.22f);
    float highlight = smoothstep_device(-0.15f, 0.65f, y - car_y) * (0.5f + 0.5f * sinf((x - car_x) * 18.0f));
    color = mix_color_device(color, mix_color_device(paint_shadow, paint, 0.65f + 0.35f * highlight), body);

    float cabin = box_mask_device(x, y, car_x - 0.08f, car_y + 0.22f, snow_scene ? 0.48f : 0.34f, 0.14f, 0.05f);
    color = mix_color_device(color, snow_scene ? Vec3(0.18f, 0.45f, 0.68f) : Vec3(0.18f, 0.34f, 0.40f), cabin * 0.75f);

    float grille = box_mask_device(x, y, car_x - (snow_scene ? 0.48f : 0.28f), car_y - 0.10f, 0.22f, 0.08f, 0.02f);
    color = mix_color_device(color, Vec3(0.015f, 0.015f, 0.018f), grille * 0.9f);

    float wheel1 = ellipse_mask_device(x, y, car_x - (snow_scene ? 0.54f : 0.38f), car_y - 0.20f, 0.16f, 0.21f, 0.08f);
    float wheel2 = ellipse_mask_device(x, y, car_x + (snow_scene ? 0.56f : 0.34f), car_y - 0.20f, 0.16f, 0.21f, 0.08f);
    color = mix_color_device(color, Vec3(0.01f, 0.01f, 0.012f), clamp(wheel1 + wheel2, 0.0f, 1.0f));
    color += Vec3(0.7f, 0.72f, 0.75f) * (ellipse_mask_device(x, y, car_x - 0.38f, car_y - 0.20f, 0.055f, 0.075f, 0.08f) +
                                           ellipse_mask_device(x, y, car_x + 0.34f, car_y - 0.20f, 0.055f, 0.075f, 0.08f)) * 0.5f;

    float headlight = ellipse_mask_device(x, y, car_x - (snow_scene ? 0.72f : 0.48f), car_y + 0.01f, 0.08f, 0.035f, 0.08f);
    color += (snow_scene ? Vec3(0.65f, 0.9f, 1.2f) : Vec3(1.0f, 0.85f, 0.45f)) * headlight * 1.2f;

    if (snow_scene) {
        float wing = box_mask_device(x, y, car_x + 0.72f, car_y + 0.34f, 0.34f, 0.035f, 0.015f);
        color = mix_color_device(color, Vec3(0.02f, 0.025f, 0.03f), wing);
    }

    float vignette = smoothstep_device(1.45f, 0.25f, sqrtf(x * x * 0.35f + y * y));
    color = color * (0.62f + 0.38f * vignette);
    return color;
}

__device__ Vec3 ray_color_iterative(Ray r, curandState* state,
                                    const Sphere* spheres, int num_spheres,
                                    const MaterialData* materials) {
    Vec3 accumulated_attenuation(1.0f, 1.0f, 1.0f);

    for (int depth = 0; depth < MAX_DEPTH; depth++) {
        HitRecord rec;
        if (hit_world(r, 0.001f, 1e30f, rec, spheres, num_spheres)) {
            Ray scattered;
            Vec3 attenuation;
            if (scatter_material(materials[rec.mat_id], r, rec, attenuation, scattered, state)) {
                accumulated_attenuation *= attenuation;
                r = scattered;
            } else {
                return Vec3(0, 0, 0);
            }
        } else {
            return accumulated_attenuation * background_color(r);
        }
    }

    return Vec3(0, 0, 0);
}

__global__ void init_rand_kernel(curandState* rand_states, int width, int height, unsigned long long seed) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int j = blockIdx.y * blockDim.y + threadIdx.y;
    if (i >= width || j >= height) return;

    int idx = j * width + i;
    curand_init(seed, idx, 0, &rand_states[idx]);
}

__global__ void render_kernel(float* framebuffer, int width, int height, int samples,
                              Camera camera, curandState* rand_states, int scene_id,
                              const Sphere* spheres, int num_spheres,
                              const MaterialData* materials) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int j = blockIdx.y * blockDim.y + threadIdx.y;
    if (i >= width || j >= height) return;

    int idx = j * width + i;
    curandState local_rand = rand_states[idx];
    Vec3 color(0, 0, 0);

    for (int s = 0; s < samples; s++) {
        float u = (i + random_float(&local_rand)) / (width - 1);
        float v = (j + random_float(&local_rand)) / (height - 1);
        if (scene_id == 3) {
            color += blackhole_color(u, v, static_cast<float>(width) / height);
        } else if (scene_id == 4) {
            color += car_cinematic_color(u, v, static_cast<float>(width) / height, false);
        } else if (scene_id == 5) {
            color += car_cinematic_color(u, v, static_cast<float>(width) / height, true);
        } else {
            Ray r = camera.get_ray(u, v, &local_rand);
            color += ray_color_iterative(r, &local_rand, spheres, num_spheres, materials);
        }
    }

    rand_states[idx] = local_rand;
    int out_row = height - 1 - j;
    int out_idx = out_row * width + i;
    framebuffer[out_idx * 3 + 0] = color.x / samples;
    framebuffer[out_idx * 3 + 1] = color.y / samples;
    framebuffer[out_idx * 3 + 2] = color.z / samples;
}

static void write_ppm(const std::string& path, const std::vector<float>& framebuffer) {
    std::ofstream out(path);
    out << "P3\n" << WIDTH << ' ' << HEIGHT << "\n255\n";
    for (int idx = 0; idx < WIDTH * HEIGHT; idx++) {
        float r = sqrtf(framebuffer[idx * 3 + 0]);
        float g = sqrtf(framebuffer[idx * 3 + 1]);
        float b = sqrtf(framebuffer[idx * 3 + 2]);

        int ir = static_cast<int>(256 * clamp(r, 0.0f, 0.999f));
        int ig = static_cast<int>(256 * clamp(g, 0.0f, 0.999f));
        int ib = static_cast<int>(256 * clamp(b, 0.0f, 0.999f));
        out << ir << ' ' << ig << ' ' << ib << '\n';
    }
}

int main(int argc, char** argv) {
    std::string output_path = "output.ppm";
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--width" && i + 1 < argc) WIDTH = std::atoi(argv[++i]);
        else if (arg == "--height" && i + 1 < argc) HEIGHT = std::atoi(argv[++i]);
        else if (arg == "--samples" && i + 1 < argc) SAMPLES = std::atoi(argv[++i]);
        else if (arg == "--output" && i + 1 < argc) output_path = argv[++i];
        else if (arg == "--scene" && i + 1 < argc) SCENE = argv[++i];
    }

    std::vector<Sphere> spheres;
    std::vector<MaterialData> materials;
    build_scene(spheres, materials, SCENE);
    int num_spheres = static_cast<int>(spheres.size());

    Vec3 lookfrom = (SCENE == "racing") ? Vec3(5.5f, 2.2f, 4.6f) :
                    (SCENE == "neon") ? Vec3(4.2f, 2.0f, 4.2f) : Vec3(13, 2, 3);
    Vec3 lookat = (SCENE == "classic") ? Vec3(0, 0, 0) : Vec3(0, 0.65f, -1.6f);
    Vec3 vup(0, 1, 0);
    float dist_to_focus = 10.0f;
    float aperture = 0.1f;
    float aspect_ratio = static_cast<float>(WIDTH) / HEIGHT;
    Camera camera(lookfrom, lookat, vup, 20.0f, aspect_ratio, aperture, dist_to_focus);

    size_t pixel_count = static_cast<size_t>(WIDTH) * HEIGHT;
    size_t framebuffer_bytes = pixel_count * 3 * sizeof(float);
    float* d_framebuffer = nullptr;
    curandState* d_rand_states = nullptr;
    Sphere* d_spheres = nullptr;
    MaterialData* d_materials = nullptr;
    CUDA_CHECK(cudaMalloc(&d_framebuffer, framebuffer_bytes));
    CUDA_CHECK(cudaMalloc(&d_rand_states, pixel_count * sizeof(curandState)));
    CUDA_CHECK(cudaMalloc(&d_spheres, spheres.size() * sizeof(Sphere)));
    CUDA_CHECK(cudaMalloc(&d_materials, materials.size() * sizeof(MaterialData)));
    CUDA_CHECK(cudaMemcpy(d_spheres, spheres.data(), spheres.size() * sizeof(Sphere), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_materials, materials.data(), materials.size() * sizeof(MaterialData), cudaMemcpyHostToDevice));

    dim3 block(16, 16);
    dim3 grid((WIDTH + block.x - 1) / block.x, (HEIGHT + block.y - 1) / block.y);

    auto start = std::chrono::high_resolution_clock::now();

    init_rand_kernel<<<grid, block>>>(d_rand_states, WIDTH, HEIGHT, 20260616ULL);
    CUDA_CHECK(cudaGetLastError());
    int scene_id = (SCENE == "blackhole") ? 3 : (SCENE == "city_drive") ? 4 : (SCENE == "snow_gt") ? 5 : 0;
    render_kernel<<<grid, block>>>(d_framebuffer, WIDTH, HEIGHT, SAMPLES, camera, d_rand_states,
                                   scene_id, d_spheres, num_spheres, d_materials);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());

    auto end = std::chrono::high_resolution_clock::now();
    double elapsed = std::chrono::duration<double>(end - start).count();

    std::vector<float> framebuffer(pixel_count * 3);
    CUDA_CHECK(cudaMemcpy(framebuffer.data(), d_framebuffer, framebuffer_bytes, cudaMemcpyDeviceToHost));
    write_ppm(output_path, framebuffer);

    CUDA_CHECK(cudaFree(d_framebuffer));
    CUDA_CHECK(cudaFree(d_rand_states));
    CUDA_CHECK(cudaFree(d_spheres));
    CUDA_CHECK(cudaFree(d_materials));

    std::cerr << "CUDA Render time: " << elapsed << " s\n";
    std::cout << "CUDA Render time: " << elapsed << " s" << std::endl;
    return 0;
}
