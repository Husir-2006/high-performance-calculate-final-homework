#pragma once
#include <cmath>
#include "hittable.h"
#include "ray.h"
#include "vec3.h"

struct Sphere : public Hittable {
    Vec3 center;
    float radius;
    int mat_id;

    Sphere() : radius(0), mat_id(0) {}
    Sphere(const Vec3& c, float r, int m) : center(c), radius(r), mat_id(m) {}

    bool hit(const Ray& r, float t_min, float t_max, HitRecord& rec) const override {
        Vec3 oc = r.origin - center;
        float a = r.direction.length_squared();
        float half_b = oc.dot(r.direction);
        float c = oc.length_squared() - radius * radius;

        float discriminant = half_b * half_b - a * c;
        if (discriminant < 0.0f) return false;
        float sqrtd = std::sqrt(discriminant);

        float root = (-half_b - sqrtd) / a;
        if (root < t_min || root > t_max) {
            root = (-half_b + sqrtd) / a;
            if (root < t_min || root > t_max) return false;
        }

        rec.t = root;
        rec.point = r.at(rec.t);
        Vec3 outward_normal = (rec.point - center) / radius;
        rec.set_face_normal(r, outward_normal);
        rec.mat_id = mat_id;
        return true;
    }
};
