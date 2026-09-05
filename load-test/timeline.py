#!/usr/bin/env python3
# k6 요청별 기록(--out csv, K6_CSV_TIME_FORMAT=unix_milli)을 요청 시작 시각 기준 0.1초 묶음으로 집계한다.
# 목적: 2초 간격 스냅샷으로는 안 보이는 지연 봉우리의 시작·끝·높이를 시간축 위에 올린다.
#
# 사용 예:
#   python3 load-test/timeline.py load-test/out/k6-timeline-<시각>.csv.gz > load-test/out/k6-timeline-<시각>-100ms.csv
#   python3 load-test/timeline.py <파일> 500        # 0.5초 묶음
#
# 출력 컬럼:
#   bin_start_ms   묶음 시작 시각 (epoch ms — GC 로그·내부 샘플·CPU 샘플과 맞추는 축)
#   t              첫 요청 기준 경과 초
#   count          이 묶음에서 시작한 요청 수
#   p50_ms / p95_ms / max_ms   그 요청들의 응답 시간
#   non2xx4xx      2xx·4xx 가 아닌 응답 수 (연결 실패는 status 0)
import csv
import gzip
import sys


def percentile(sorted_values, q):
    if not sorted_values:
        return 0.0
    idx = round((len(sorted_values) - 1) * q)
    return sorted_values[idx]


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: timeline.py <k6 csv[.gz]> [bin_ms=100]")
    path = sys.argv[1]
    bin_ms = int(sys.argv[2]) if len(sys.argv) > 2 else 100

    opener = gzip.open if path.endswith(".gz") else open
    bins = {}
    with opener(path, "rt", newline="") as f:
        for row in csv.DictReader(f):
            if row["metric_name"] != "http_req_duration":
                continue
            end_ms = int(row["timestamp"])
            dur = float(row["metric_value"])
            start_ms = end_ms - int(dur)
            key = start_ms - start_ms % bin_ms
            status = int(row["status"] or 0)
            durations, bad = bins.setdefault(key, ([], 0))
            durations.append(dur)
            if not (200 <= status < 500):
                bins[key] = (durations, bad + 1)

    if not bins:
        sys.exit("http_req_duration 행이 없음: " + path)

    first = min(bins)
    out = csv.writer(sys.stdout)
    out.writerow(["bin_start_ms", "t", "count", "p50_ms", "p95_ms", "max_ms", "non2xx4xx"])
    for key in sorted(bins):
        durations, bad = bins[key]
        durations.sort()
        out.writerow([
            key,
            f"{(key - first) / 1000:.1f}",
            len(durations),
            f"{percentile(durations, 0.5):.1f}",
            f"{percentile(durations, 0.95):.1f}",
            f"{durations[-1]:.1f}",
            bad,
        ])


if __name__ == "__main__":
    main()
