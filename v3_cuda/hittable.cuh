#pragma once

// CUDA 版避免虚函数层级，HitRecord 与 Sphere::hit 实现在 sphere.cuh 中。
// 该头文件用于保持与 V1/V2 的目录命名和 PLANNING.md 结构一致。
#include "sphere.cuh"
