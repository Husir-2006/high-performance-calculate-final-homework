#pragma once
#include <cmath>
#include <cstdlib>
#include <limits>
#include <random>
#include "vec3.h"

constexpr float INF = std::numeric_limits<float>::infinity();
constexpr float PI = 3.1415926535897932385f;

inline float random_float() {
    static thread_local std::mt19937 rng(std::random_device{}());
    static thread_local std::uniform_real_distribution<float> dist(0.0f, 1.0f);
    return dist(rng);
}

inline float random_float(float min, float max) {
    return min + (max - min) * random_float();
}

inline Vec3 random_vec3() { return Vec3(random_float(), random_float(), random_float()); }

inline Vec3 random_vec3(float min, float max) {
    return Vec3(random_float(min, max), random_float(min, max), random_float(min, max));
}

inline Vec3 random_in_unit_sphere() {
    while (true) {
        Vec3 p = random_vec3(-1.0f, 1.0f);
        if (p.length_squared() < 1.0f) return p;
    }
}

inline Vec3 random_unit_vector() { return random_in_unit_sphere().normalize(); }

inline Vec3 random_in_unit_disk() {
    while (true) {
        Vec3 p(random_float(-1.0f, 1.0f), random_float(-1.0f, 1.0f), 0.0f);
        if (p.length_squared() < 1.0f) return p;
    }
}

inline float clamp(float x, float min, float max) {
    if (x < min) return min;
    if (x > max) return max;
    return x;
}

inline float degrees_to_radians(float degrees) { return degrees * PI / 180.0f; }
