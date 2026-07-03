#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="${ROOT_DIR}/results"
WIDTH="${WIDTH:-1280}"
HEIGHT="${HEIGHT:-720}"
SAMPLES="${SAMPLES:-128}"
CUDA_ARCH="${CUDA_ARCH:-sm_80}"
NVCC="${NVCC:-nvcc}"

mkdir -p "${RESULTS_DIR}"

if [[ ! -x "${ROOT_DIR}/v3_cuda/v3_cuda" ]]; then
    "${NVCC}" -O3 -arch="${CUDA_ARCH}" "${ROOT_DIR}/v3_cuda/main.cu" -o "${ROOT_DIR}/v3_cuda/v3_cuda"
fi

for scene in blackhole city_drive snow_gt; do
    echo "[render] ${scene} ${WIDTH}x${HEIGHT} samples=${SAMPLES}"
    "${ROOT_DIR}/v3_cuda/v3_cuda" \
        --width "${WIDTH}" \
        --height "${HEIGHT}" \
        --samples "${SAMPLES}" \
        --scene "${scene}" \
        --output "${RESULTS_DIR}/${scene}_showcase.ppm"
done

echo "[done] showcase images written to ${RESULTS_DIR}"
