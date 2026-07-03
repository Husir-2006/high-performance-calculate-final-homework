#pragma once
#include "ray.h"
#include "utils.h"
#include "vec3.h"

struct Camera {
    Vec3 origin;
    Vec3 lower_left_corner;
    Vec3 horizontal;
    Vec3 vertical;
    Vec3 u, v, w;
    float lens_radius;

    Camera(Vec3 lookfrom, Vec3 lookat, Vec3 vup,
           float vfov_degrees, float aspect_ratio,
           float aperture, float focus_dist) {
        float theta = degrees_to_radians(vfov_degrees);
        float h = std::tan(theta / 2.0f);
        float viewport_height = 2.0f * h;
        float viewport_width = aspect_ratio * viewport_height;

        w = (lookfrom - lookat).normalize();
        u = vup.cross(w).normalize();
        v = w.cross(u);

        origin = lookfrom;
        horizontal = u * (viewport_width * focus_dist);
        vertical = v * (viewport_height * focus_dist);
        lower_left_corner = origin - horizontal / 2.0f - vertical / 2.0f - w * focus_dist;

        lens_radius = aperture / 2.0f;
    }

    Ray get_ray(float s, float t) const {
        Vec3 rd = random_in_unit_disk() * lens_radius;
        Vec3 offset = u * rd.x + v * rd.y;
        return Ray(origin + offset,
                   lower_left_corner + horizontal * s + vertical * t - origin - offset);
    }
};
