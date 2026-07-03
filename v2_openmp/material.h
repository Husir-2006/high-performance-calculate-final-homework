#pragma once
#include <cmath>
#include "hittable.h"
#include "ray.h"
#include "utils.h"
#include "vec3.h"

struct Material {
    virtual ~Material() = default;
    virtual bool scatter(const Ray& r_in, const HitRecord& rec,
                          Vec3& attenuation, Ray& scattered) const = 0;
};

struct Lambertian : public Material {
    Vec3 albedo;
    explicit Lambertian(const Vec3& a) : albedo(a) {}

    bool scatter(const Ray&, const HitRecord& rec,
                 Vec3& attenuation, Ray& scattered) const override {
        Vec3 scatter_direction = rec.normal + random_unit_vector();
        if (scatter_direction.near_zero()) scatter_direction = rec.normal;
        scattered = Ray(rec.point, scatter_direction);
        attenuation = albedo;
        return true;
    }
};

struct Metal : public Material {
    Vec3 albedo;
    float fuzz;
    Metal(const Vec3& a, float f) : albedo(a), fuzz(f < 1.0f ? f : 1.0f) {}

    bool scatter(const Ray& r_in, const HitRecord& rec,
                 Vec3& attenuation, Ray& scattered) const override {
        Vec3 reflected = Vec3::reflect(r_in.direction.normalize(), rec.normal);
        scattered = Ray(rec.point, reflected + random_in_unit_sphere() * fuzz);
        attenuation = albedo;
        return scattered.direction.dot(rec.normal) > 0.0f;
    }
};

struct Dielectric : public Material {
    float ir; // index of refraction
    explicit Dielectric(float index_of_refraction) : ir(index_of_refraction) {}

    bool scatter(const Ray& r_in, const HitRecord& rec,
                 Vec3& attenuation, Ray& scattered) const override {
        attenuation = Vec3(1.0f, 1.0f, 1.0f);
        float refraction_ratio = rec.front_face ? (1.0f / ir) : ir;

        Vec3 unit_direction = r_in.direction.normalize();
        float cos_theta = std::fmin((-unit_direction).dot(rec.normal), 1.0f);
        float sin_theta = std::sqrt(1.0f - cos_theta * cos_theta);

        bool cannot_refract = refraction_ratio * sin_theta > 1.0f;
        Vec3 direction;

        if (cannot_refract || reflectance(cos_theta, refraction_ratio) > random_float()) {
            direction = Vec3::reflect(unit_direction, rec.normal);
        } else {
            direction = Vec3::refract(unit_direction, rec.normal, refraction_ratio);
        }

        scattered = Ray(rec.point, direction);
        return true;
    }

private:
    static float reflectance(float cosine, float ref_idx) {
        // Schlick 近似
        float r0 = (1.0f - ref_idx) / (1.0f + ref_idx);
        r0 = r0 * r0;
        return r0 + (1.0f - r0) * std::pow((1.0f - cosine), 5.0f);
    }
};
