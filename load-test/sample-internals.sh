#!/usr/bin/env bash
# 부하 중 앱 내부(HikariCP)와 DB 내부(pg_stat_activity)를 1초 간격으로 샘플링해 CSV 로 남긴다.
# 목적: 외부 지연(k6)이 "커넥션 풀 대기"에서 나오는지 "DB 행 락 대기"에서 나오는지 가른다.
#
# 사용 예 (measure.sh 와 같이):
#   load-test/sample-internals.sh 40 load-test/out/internals.csv &   # 40초 동안 샘플링
#   RESET_STOCK=106 load-test/measure.sh
#   wait
#
# 인자: $1 지속 시간(초, 기본 40)  $2 출력 CSV (기본 load-test/out/internals-<시각>.csv)
# 환경변수: BASE_URL (기본 http://localhost:8080), PSQL (기본 ~/.local/opt/pgsql-runner/psql)
#
# 컬럼:
#   t                     경과 초 (실제 벽시계 기준 — 한 바퀴가 1초를 넘길 수 있어 인덱스가 아닌 시각 차로 기록)
#   pool_active           HikariCP 사용 중 커넥션 수 (최대 = maximum-pool-size)
#   pool_pending          커넥션을 기다리는 스레드 수 (>0 이면 풀 대기 발생)
#   pool_acquire_avg_ms   이 1초 동안 커넥션 획득에 걸린 평균 ms (acquire 누계 델타 / 횟수 델타)
#   db_active             pg_stat_activity 에서 state='active' 세션 수
#   db_lock_wait          그중 wait_event_type='Lock' 으로 행 락을 기다리는 세션 수
#   db_idle_in_tx         'idle in transaction' 세션 수 (트랜잭션 열어 둔 채 앱 쪽에서 작업 중)
set -uo pipefail

cd "$(dirname "$0")/.."
DUR="${1:-40}"
OUT="${2:-load-test/out/internals-$(date +%Y%m%d-%H%M%S).csv}"
BASE_URL="${BASE_URL:-http://localhost:8080}"
PSQL="${PSQL:-$HOME/.local/opt/pgsql-runner/psql}"; [ -x "$PSQL" ] || PSQL=psql
mkdir -p "$(dirname "$OUT")"

metric() { # $1 metric name, $2 statistic
    curl -s "$BASE_URL/actuator/metrics/$1" \
      | python3 -c "import sys,json; d=json.load(sys.stdin); print(next(x['value'] for x in d['measurements'] if x['statistic']=='$2'))" 2>/dev/null || echo 0
}
dbcounts() { # 한 줄: active lock_wait idle_in_tx
    "$PSQL" -c "SELECT count(*) FILTER (WHERE state='active') AS a,
                       count(*) FILTER (WHERE state='active' AND wait_event_type='Lock') AS l,
                       count(*) FILTER (WHERE state='idle in transaction') AS i
                FROM pg_stat_activity WHERE datname='ecommerce' AND pid <> pg_backend_pid()" \
      | grep -E '^[[:space:]]*[0-9]+[[:space:]]*\|' | tr -d ' ' | tr '|' ' '
}

echo "t,pool_active,pool_pending,pool_acquire_avg_ms,db_active,db_lock_wait,db_idle_in_tx" > "$OUT"
prev_cnt=$(metric hikaricp.connections.acquire COUNT)
prev_tot=$(metric hikaricp.connections.acquire TOTAL_TIME)
START=$(date +%s.%N)
while :; do
    sleep 1
    t=$(python3 -c "print(round($(date +%s.%N)-$START,1))")
    [ "${t%.*}" -ge "$DUR" ] && break
    act=$(metric hikaricp.connections.active VALUE)
    pend=$(metric hikaricp.connections.pending VALUE)
    cnt=$(metric hikaricp.connections.acquire COUNT)
    tot=$(metric hikaricp.connections.acquire TOTAL_TIME)
    avg=$(python3 -c "dc=$cnt-$prev_cnt; print(round(($tot-$prev_tot)*1000/dc,1) if dc>0 else 0)")
    prev_cnt=$cnt; prev_tot=$tot
    read -r dba dbl dbi <<< "$(dbcounts)"
    echo "$t,${act%.*},${pend%.*},$avg,${dba:-0},${dbl:-0},${dbi:-0}" >> "$OUT"
done
echo "== 샘플 저장: $OUT"
