#!/usr/bin/env bash
# 측정용 앱 재빌드 + 재기동. (기존 인스턴스가 있으면 내리고) bootJar 를 다시 만들어 백그라운드로 띄운다.
#
# 사용 예:
#   load-test/restart-app.sh            # 빌드 + 재기동
#   SKIP_BUILD=1 load-test/restart-app.sh   # 빌드 생략, 재기동만
#
# 환경변수 (모두 선택):
#   JAVA        java 실행 파일                (기본 ~/jdk-25/bin/java, 없으면 PATH 의 java)
#   APP_LOG     앱 로그 경로                   (기본 ~/.local/var/api-server.log)
#   APP_PID     pid 파일 경로                  (기본 ~/.local/var/api-server.pid)
#   EXTRA_ARGS  앱에 덧붙일 인자
#   JAR         실행할 jar 경로 (기본 modules/api-server/build/libs/api-server-0.0.1-SNAPSHOT.jar — 다른 브랜치 빌드로 대조 측정할 때 지정)
#
# Redis(Redisson)/Kafka 자동설정은 제외한다 — 측정 환경에 해당 서버가 없고, 현재 phase 코드가 쓰지 않는다.
# 코드가 Redis/Kafka 를 쓰기 시작하는 phase 부터는 이 제외 목록을 걷어내고 서버를 띄워야 한다.
set -euo pipefail

cd "$(dirname "$0")/.."

JAVA="${JAVA:-$HOME/jdk-25/bin/java}"; [ -x "$JAVA" ] || JAVA=java
APP_LOG="${APP_LOG:-$HOME/.local/var/api-server.log}"
APP_PID="${APP_PID:-$HOME/.local/var/api-server.pid}"
JAR="${JAR:-modules/api-server/build/libs/api-server-0.0.1-SNAPSHOT.jar}"

EXCLUDES=org.redisson.spring.starter.RedissonAutoConfigurationV2
EXCLUDES+=,org.springframework.boot.data.redis.autoconfigure.DataRedisAutoConfiguration
EXCLUDES+=,org.springframework.boot.data.redis.autoconfigure.DataRedisRepositoriesAutoConfiguration
EXCLUDES+=,org.springframework.boot.kafka.autoconfigure.KafkaAutoConfiguration

if [ -z "${SKIP_BUILD:-}" ]; then
    echo "== bootJar 빌드"
    ./gradlew :api-server:bootJar -q -x test 2>&1 | grep -v '^WARNING' || true
    [ -f "$JAR" ] || { echo "!! 빌드 산출물 없음: $JAR" >&2; exit 1; }
fi

if [ -f "$APP_PID" ]; then
    OLD=$(sed 's/^pid=//' "$APP_PID")
    if kill -0 "$OLD" 2>/dev/null; then
        echo "== 기존 앱 종료 (pid $OLD)"
        kill "$OLD"
        for _ in $(seq 1 30); do kill -0 "$OLD" 2>/dev/null || break; sleep 1; done
    fi
fi

echo "== 앱 기동 (로그: $APP_LOG)"
mkdir -p "$(dirname "$APP_LOG")"
: > "$APP_LOG"
# shellcheck disable=SC2086
nohup "$JAVA" -jar "$JAR" \
    --spring.autoconfigure.exclude="$EXCLUDES" \
    --logging.level.org.jooq.tools.LoggerListener=WARN \
    ${EXTRA_ARGS:-} >> "$APP_LOG" 2>&1 &
echo "pid=$!" > "$APP_PID"

for _ in $(seq 1 60); do
    if grep -q "Started ApiServerApplication" "$APP_LOG"; then
        echo "== 기동 완료 (pid $(cat "$APP_PID" | sed 's/^pid=//'))"
        exit 0
    fi
    if grep -q "APPLICATION FAILED TO START" "$APP_LOG"; then
        echo "!! 기동 실패 — 로그 확인: $APP_LOG" >&2
        tail -30 "$APP_LOG" >&2
        exit 1
    fi
    sleep 2
done
echo "!! 120초 내 기동 확인 실패 — 로그 확인: $APP_LOG" >&2
exit 1
