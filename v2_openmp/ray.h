#pragma once
#include "vec3.h"

struct Ray {
    Vec3 origin, direction;

    Ray() {}
    Ray(const Vec3& o, const Vec3& d) : origin(o), direction(d) {}

    Vec3 at(float t) const { return origin + direction * t; }
};
