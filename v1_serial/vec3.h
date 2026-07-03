#pragma once
#include <cmath>
#include <iostream>

struct Vec3 {
    float x, y, z;

    Vec3() : x(0), y(0), z(0) {}
    Vec3(float x_, float y_, float z_) : x(x_), y(y_), z(z_) {}

    Vec3 operator+(const Vec3& v) const { return Vec3(x + v.x, y + v.y, z + v.z); }
    Vec3 operator-(const Vec3& v) const { return Vec3(x - v.x, y - v.y, z - v.z); }
    Vec3 operator-() const { return Vec3(-x, -y, -z); }
    Vec3 operator*(float t) const { return Vec3(x * t, y * t, z * t); }
    Vec3 operator*(const Vec3& v) const { return Vec3(x * v.x, y * v.y, z * v.z); }
    Vec3 operator/(float t) const { return Vec3(x / t, y / t, z / t); }

    Vec3& operator+=(const Vec3& v) { x += v.x; y += v.y; z += v.z; return *this; }
    Vec3& operator*=(float t) { x *= t; y *= t; z *= t; return *this; }
    Vec3& operator*=(const Vec3& v) { x *= v.x; y *= v.y; z *= v.z; return *this; }
    Vec3& operator/=(float t) { return *this *= (1.0f / t); }

    float dot(const Vec3& v) const { return x * v.x + y * v.y + z * v.z; }

    Vec3 cross(const Vec3& v) const {
        return Vec3(y * v.z - z * v.y,
                    z * v.x - x * v.z,
                    x * v.y - y * v.x);
    }

    float length_squared() const { return x * x + y * y + z * z; }
    float length() const { return std::sqrt(length_squared()); }

    Vec3 normalize() const {
        float len = length();
        return *this / len;
    }

    bool near_zero() const {
        const float eps = 1e-8f;
        return (std::fabs(x) < eps) && (std::fabs(y) < eps) && (std::fabs(z) < eps);
    }

    static Vec3 reflect(const Vec3& v, const Vec3& n) {
        return v - n * (2.0f * v.dot(n));
    }

    static Vec3 refract(const Vec3& uv, const Vec3& n, float etai_over_etat) {
        float cos_theta = std::fmin((-uv).dot(n), 1.0f);
        Vec3 r_out_perp = (uv + n * cos_theta) * etai_over_etat;
        Vec3 r_out_parallel = n * (-std::sqrt(std::fabs(1.0f - r_out_perp.length_squared())));
        return r_out_perp + r_out_parallel;
    }
};

inline Vec3 operator*(float t, const Vec3& v) { return v * t; }

inline std::ostream& operator<<(std::ostream& out, const Vec3& v) {
    return out << v.x << ' ' << v.y << ' ' << v.z;
}
