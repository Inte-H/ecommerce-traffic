#!/usr/bin/env python3
# 부하 중 앱(java)·부하 발생기(k6)·PostgreSQL 이 각각 CPU 를 얼마나 쓰는지 /proc 에서 짧은 간격으로 읽어 CSV 로 남긴다.
# 목적: 지연 봉우리 순간에 앱이 멈춘 것인지(java 몫 ≈ 0, 전체 여유) 다른 프로세스가 앱을 밀어낸 것인지(전체가 코어 수에 붙음) 가른다.
# /proc 파일 읽기만 하므로 sample-internals.sh 와 달리 프로세스를 띄우지 않아 0.2초 간격도 부담이 거의 없다.
#
# 사용 예 (measure.sh 와 같이):
#   python3 load-test/sample-cpu.py 40 load-test/out/cpu.csv &    # 40초 동안 0.2초 간격
#   RESET_STOCK=106 load-test/measure.sh
#   wait
#
# 인자: $1 지속 시간(초, 기본 40)  $2 출력 CSV (기본 load-test/out/cpu-<시각>.csv)  $3 간격(초, 기본 0.2)
#
# 컬럼 (값은 "코어 수" 단위 — 1.0 이면 코어 하나를 꽉 쓴 셈, 상한은 nproc):
#   ts         샘플 시각 (epoch ms)
#   t          경과 초
#   java       api-server JVM
#   k6         k6 프로세스
#   postgres   postmaster + 백엔드 전부의 합
#   other      그 외 전부 (이 샘플러, 셸, WSL 잡음)
#   total      머신 전체 사용량 (java + k6 + postgres + other)
#   ncpu       코어 수 (total 이 여기 붙으면 CPU 경합)
import os
import sys
import time
from datetime import datetime

CLK_TCK = os.sysconf("SC_CLK_TCK")
NCPU = os.cpu_count()

MATCHERS = {
    "java": lambda argv: "java" in os.path.basename(argv[0]) and any("api-server" in a for a in argv),
    "k6": lambda argv: os.path.basename(argv[0]) == "k6",
    "postgres": lambda argv: os.path.basename(argv[0]).startswith("postgres"),
}


def scan_pids():
    found = {name: set() for name in MATCHERS}
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        try:
            with open(f"/proc/{entry}/cmdline", "rb") as f:
                argv = f.read().split(b"\0")
        except OSError:
            continue
        argv = [a.decode(errors="replace") for a in argv if a]
        if not argv:
            continue
        for name, match in MATCHERS.items():
            if match(argv):
                found[name].add(int(entry))
    return found


def proc_ticks(pid):
    try:
        with open(f"/proc/{pid}/stat") as f:
            fields = f.read().rsplit(")", 1)[1].split()
    except OSError:
        return None
    return int(fields[11]) + int(fields[12])  # utime + stime (comm 뒤 필드 기준 14,15번째)


def total_ticks():
    with open("/proc/stat") as f:
        fields = f.readline().split()[1:]
    busy = sum(int(x) for x in fields) - int(fields[3]) - int(fields[4])  # idle, iowait 제외
    return busy


def main():
    duration = float(sys.argv[1]) if len(sys.argv) > 1 else 40
    out_path = sys.argv[2] if len(sys.argv) > 2 else f"load-test/out/cpu-{datetime.now():%Y%m%d-%H%M%S}.csv"
    interval = float(sys.argv[3]) if len(sys.argv) > 3 else 0.2
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)

    pids = scan_pids()
    prev_proc = {}
    prev_total = total_ticks()
    prev_wall = time.time()
    start = prev_wall
    last_scan = prev_wall

    with open(out_path, "w") as out:
        out.write("ts,t,java,k6,postgres,other,total,ncpu\n")
        while True:
            time.sleep(interval)
            now = time.time()
            if now - start >= duration:
                break
            if now - last_scan >= 1.0:
                pids = scan_pids()
                last_scan = now

            elapsed_ticks = (now - prev_wall) * CLK_TCK
            cur_total = total_ticks()
            cores = {}
            for name, pid_set in pids.items():
                delta = 0
                for pid in pid_set:
                    ticks = proc_ticks(pid)
                    if ticks is None:
                        continue
                    if pid in prev_proc:
                        delta += ticks - prev_proc[pid]
                    prev_proc[pid] = ticks
                cores[name] = delta / elapsed_ticks
            total = (cur_total - prev_total) / elapsed_ticks
            other = max(total - sum(cores.values()), 0.0)

            out.write(
                f"{int(now * 1000)},{now - start:.1f},"
                f"{cores['java']:.2f},{cores['k6']:.2f},{cores['postgres']:.2f},"
                f"{other:.2f},{total:.2f},{NCPU}\n"
            )
            out.flush()
            prev_total, prev_wall = cur_total, now

    print(f"== 샘플 저장: {out_path}")


if __name__ == "__main__":
    main()
