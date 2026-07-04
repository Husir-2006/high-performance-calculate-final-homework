#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="${ROOT_DIR}/results"
WIDTH="${WIDTH:-400}"
HEIGHT="${HEIGHT:-300}"
SAMPLES="${SAMPLES:-64}"
SCENE="${SCENE:-classic}"
CXX="${CXX:-g++}"
NVCC="${NVCC:-nvcc}"
CUDA_ARCH="${CUDA_ARCH:-sm_80}"

mkdir -p "${RESULTS_DIR}"

CSV="${RESULTS_DIR}/benchmark_results.csv"
echo "version,threads,width,height,samples,time_seconds,speedup" > "${CSV}"

extract_time() {
    sed -n 's/.*Render time: \([0-9.][0-9.]*\) s.*/\1/p' | tail -n 1
}

compile_cpu() {
    echo "[build] v1_serial"
    "${CXX}" -O2 -std=c++17 "${ROOT_DIR}/v1_serial/main.cpp" -o "${ROOT_DIR}/v1_serial/v1_serial"

    echo "[build] v2_openmp"
    "${CXX}" -O2 -std=c++17 -fopenmp "${ROOT_DIR}/v2_openmp/main.cpp" -o "${ROOT_DIR}/v2_openmp/v2_openmp"
}

compile_cuda() {
    if command -v "${NVCC}" >/dev/null 2>&1; then
        echo "[build] v3_cuda (${CUDA_ARCH})"
        "${NVCC}" -O3 -arch="${CUDA_ARCH}" "${ROOT_DIR}/v3_cuda/main.cu" -o "${ROOT_DIR}/v3_cuda/v3_cuda"
        return 0
    fi
    echo "[skip] nvcc not found; CUDA benchmark skipped" >&2
    return 1
}

run_v1() {
    echo "[run] v1_serial"
    pushd "${ROOT_DIR}/v1_serial" >/dev/null
    output=$(./v1_serial --width "${WIDTH}" --height "${HEIGHT}" --samples "${SAMPLES}" --scene "${SCENE}" 2>&1)
    popd >/dev/null
    time_s=$(printf '%s\n' "${output}" | extract_time)
    cp "${ROOT_DIR}/v1_serial/output.ppm" "${RESULTS_DIR}/v1_output.ppm"
    echo "v1_serial,1,${WIDTH},${HEIGHT},${SAMPLES},${time_s},1.0000" >> "${CSV}"
    SERIAL_TIME="${time_s}"
}

run_v2() {
    for threads in 1 2 4 8 16 32; do
        echo "[run] v2_openmp threads=${threads}"
        pushd "${ROOT_DIR}/v2_openmp" >/dev/null
        output=$(OMP_NUM_THREADS="${threads}" ./v2_openmp --width "${WIDTH}" --height "${HEIGHT}" --samples "${SAMPLES}" --scene "${SCENE}" 2>&1)
        popd >/dev/null
        time_s=$(printf '%s\n' "${output}" | extract_time)
        speedup=$(awk -v base="${SERIAL_TIME}" -v t="${time_s}" 'BEGIN { printf "%.4f", base / t }')
        echo "v2_openmp,${threads},${WIDTH},${HEIGHT},${SAMPLES},${time_s},${speedup}" >> "${CSV}"
        if [[ "${threads}" == "32" || ! -f "${RESULTS_DIR}/v2_output.ppm" ]]; then
            cp "${ROOT_DIR}/v2_openmp/output.ppm" "${RESULTS_DIR}/v2_output.ppm"
        fi
    done
}

run_v3() {
    if [[ ! -x "${ROOT_DIR}/v3_cuda/v3_cuda" ]]; then
        return 0
    fi
    echo "[run] v3_cuda"
    output=$("${ROOT_DIR}/v3_cuda/v3_cuda" --width "${WIDTH}" --height "${HEIGHT}" --samples "${SAMPLES}" --scene "${SCENE}" --output "${RESULTS_DIR}/v3_output.ppm" 2>&1)
    time_s=$(printf '%s\n' "${output}" | extract_time)
    speedup=$(awk -v base="${SERIAL_TIME}" -v t="${time_s}" 'BEGIN { printf "%.4f", base / t }')
    echo "v3_cuda,gpu,${WIDTH},${HEIGHT},${SAMPLES},${time_s},${speedup}" >> "${CSV}"
}

compile_cpu
CUDA_AVAILABLE=0
if compile_cuda; then
    CUDA_AVAILABLE=1
fi

run_v1
run_v2
if [[ "${CUDA_AVAILABLE}" == "1" ]]; then
    run_v3
fi

echo "[done] results written to ${CSV}"
