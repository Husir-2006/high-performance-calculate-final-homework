#pragma once
#include <curand_kernel.h>
#include "ray.cuh"
#include "sphere.cuh"
#include "vec3.cuh"

enum MaterialType {
    MAT_LAMBERTIAN = 0,
    MAT_METAL = 1,
    MAT_DIELECTRIC = 2
};

struct MaterialData {
    int type;
    Vec3 albedo;
    float fuzz;
    float ir;
};

__device__ inline float random_float(curandState* state) {
    return curand_uniform(state);
}

__device__ inline float random_float(curandState* state, float min_value, float max_value) {
    return min_value + (max_value - min_value) * random_float(state);
}

__device__ inline Vec3 random_vec3(curandState* state, float min_value, float max_value) {
    return Vec3(random_float(state, min_value, max_value),
                random_float(state, min_value, max_value),
                random_float(state, min_value, max_value));
}

__device__ inline Vec3 random_in_unit_sphere(curandState* state) {
    while (true) {
        Vec3 p = random_vec3(state, -1.0f, 1.0f);
        if (p.length_squared() < 1.0f) return p;
    }
}

__device__ inline Vec3 random_unit_vector(curandState* state) {
    return random_in_unit_sphere(state).normalize();
}

__device__ inline Vec3 random_in_unit_disk(curandState* state) {
    while (true) {
        Vec3 p(random_float(state, -1.0f, 1.0f), random_float(state, -1.0f, 1.0f), 0.0f);
        if (p.length_squared() < 1.0f) return p;
    }
}

__device__ inline float reflectance(float cosine, float ref_idx) {
    float r0 = (1.0f - ref_idx) / (1.0f + ref_idx);
    r0 = r0 * r0;
    return r0 + (1.0f - r0) * powf(1.0f - cosine, 5.0f);
}

__device__ inline bool scatter_material(const MaterialData& mat, const Ray& r_in,
                                        const HitRecord& rec, Vec3& attenuation,
                                        Ray& scattered, curandState* state) {
    if (mat.type == MAT_LAMBERTIAN) {
        Vec3 scatter_direction = rec.normal + random_unit_vector(state);
        if (scatter_direction.near_zero()) scatter_direction = rec.normal;
        scattered = Ray(rec.point, scatter_direction);
        attenuation = mat.albedo;
        return true;
    }

    if (mat.type == MAT_METAL) {
        Vec3 reflected = reflect(r_in.direction.normalize(), rec.normal);
        scattered = Ray(rec.point, reflected + random_in_unit_sphere(state) * mat.fuzz);
        attenuation = mat.albedo;
        return scattered.direction.dot(rec.normal) > 0.0f;
    }

    attenuation = Vec3(1.0f, 1.0f, 1.0f);
    float refraction_ratio = rec.front_face ? (1.0f / mat.ir) : mat.ir;
    Vec3 unit_direction = r_in.direction.normalize();
    float cos_theta = fminf((-unit_direction).dot(rec.normal), 1.0f);
    float sin_theta = sqrtf(1.0f - cos_theta * cos_theta);
    bool cannot_refract = refraction_ratio * sin_theta > 1.0f;
    Vec3 direction;

    if (cannot_refract || reflectance(cos_theta, refraction_ratio) > random_float(state)) {
        direction = reflect(unit_direction, rec.normal);
    } else {
        direction = refract(unit_direction, rec.normal, refraction_ratio);
    }

    scattered = Ray(rec.point, direction);
    return true;
}
