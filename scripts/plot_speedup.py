#!/usr/bin/env python3
import csv
from pathlib import Path

import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "results" / "benchmark_results.csv"
OUT_PATH = ROOT / "results" / "speedup.png"


def load_rows():
    with CSV_PATH.open(newline="") as f:
        return list(csv.DictReader(f))


def main():
    rows = load_rows()
    if not rows:
        raise SystemExit("benchmark_results.csv is empty")

    omp_rows = [r for r in rows if r["version"] == "v2_openmp"]
    cuda_rows = [r for r in rows if r["version"] == "v3_cuda"]

    plt.figure(figsize=(8, 5))
    if omp_rows:
        threads = [int(r["threads"]) for r in omp_rows]
        speedups = [float(r["speedup"]) for r in omp_rows]
        plt.plot(threads, speedups, marker="o", linewidth=2, label="OpenMP")
        plt.plot(threads, threads, linestyle="--", color="gray", linewidth=1, label="Ideal linear")

    if cuda_rows:
        cuda_speedup = float(cuda_rows[0]["speedup"])
        plt.axhline(cuda_speedup, color="#d62728", linestyle="-.", linewidth=2, label=f"CUDA {cuda_speedup:.2f}x")

    plt.xlabel("OpenMP threads")
    plt.ylabel("Speedup vs V1 serial")
    plt.title("Ray Tracing HPC Speedup")
    plt.grid(True, linestyle=":", alpha=0.6)
    plt.legend()
    plt.tight_layout()
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(OUT_PATH, dpi=200)
    print(f"saved {OUT_PATH}")


if __name__ == "__main__":
    main()
