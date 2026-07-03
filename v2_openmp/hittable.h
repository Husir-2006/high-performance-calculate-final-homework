#pragma once
#include <memory>
#include <vector>
#include "ray.h"
#include "vec3.h"

struct HitRecord {
    Vec3 point;
    Vec3 normal;
    float t;
    int mat_id;
    bool front_face;

    void set_face_normal(const Ray& r, const Vec3& outward_normal) {
        front_face = r.direction.dot(outward_normal) < 0.0f;
        normal = front_face ? outward_normal : -outward_normal;
    }
};

struct Hittable {
    virtual ~Hittable() = default;
    virtual bool hit(const Ray& r, float t_min, float t_max, HitRecord& rec) const = 0;
};

struct HittableList : public Hittable {
    std::vector<std::shared_ptr<Hittable>> objects;

    HittableList() = default;

    void add(std::shared_ptr<Hittable> obj) { objects.push_back(obj); }
    void clear() { objects.clear(); }

    bool hit(const Ray& r, float t_min, float t_max, HitRecord& rec) const override {
        HitRecord temp_rec;
        bool hit_anything = false;
        float closest_so_far = t_max;

        for (const auto& obj : objects) {
            if (obj->hit(r, t_min, closest_so_far, temp_rec)) {
                hit_anything = true;
                closest_so_far = temp_rec.t;
                rec = temp_rec;
            }
        }
        return hit_anything;
    }
};
