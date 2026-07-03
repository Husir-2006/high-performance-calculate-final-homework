#pragma once
#include "ray.cuh"
#include "vec3.cuh"

struct HitRecord {
    Vec3 point;
    Vec3 normal;
    float t;
    int mat_id;
    bool front_face;

    __device__ void set_face_normal(const Ray& r, const Vec3& outward_normal) {
        front_face = r.direction.dot(outward_normal) < 0.0f;
        normal = front_face ? outward_normal : -outward_normal;
    }
};

struct Sphere {
    Vec3 center;
    float radius;
    int mat_id;

    __host__ __device__ Sphere() : center(), radius(0.0f), mat_id(0) {}
    __host__ __device__ Sphere(const Vec3& c, float r, int m) : center(c), radius(r), mat_id(m) {}

    __device__ bool hit(const Ray& r, float t_min, float t_max, HitRecord& rec) const {
        Vec3 oc = r.origin - center;
        float a = r.direction.length_squared();
        float half_b = oc.dot(r.direction);
        float c = oc.length_squared() - radius * radius;
        float discriminant = half_b * half_b - a * c;
        if (discriminant < 0.0f) return false;

        float sqrtd = sqrtf(discriminant);
        float root = (-half_b - sqrtd) / a;
        if (root < t_min || root > t_max) {
            root = (-half_b + sqrtd) / a;
            if (root < t_min || root > t_max) return false;
        }

        rec.t = root;
        rec.point = r.at(root);
        Vec3 outward_normal = (rec.point - center) / radius;
        rec.set_face_normal(r, outward_normal);
        rec.mat_id = mat_id;
        return true;
    }
};
