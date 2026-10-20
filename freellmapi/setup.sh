#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# freellmapi — on-premise Docker Compose 설치
#   사용법: ./setup.sh [설치 디렉터리]
#   기본값: ~/freellmapi
# 상세:   https://github.com/tashfeenahmed/freellmapi#readme
#         https://github.com/Juser0/setup-instructions#1-freellmapi-docker-on-premise
# ─────────────────────────────────────────────────────────────
set -euo pipefail

# 이 스크립트가 있는 디렉터리 (cd 하기 전에 잡아야 한다)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTALL_DIR="${1:-${INSTALL_DIR:-$HOME/freellmapi}}"

command -v docker >/dev/null || { echo "docker 없음 — Docker 24+ 설치"; exit 1; }
command -v openssl >/dev/null || { echo "openssl 없음 — 암호화 키 생성에 필요"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "docker compose(v2) 가 없다 — 플러그인 설치"; exit 1; }

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

if [ ! -f docker-compose.yml ]; then
  echo "▸ compose 파일 준비"
  if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    cp "$SCRIPT_DIR/docker-compose.yml" .
  else
    echo "▸ 원본 저장소에서 내려받기"
    curl -fsSL https://raw.githubusercontent.com/Juser0/setup-instructions/main/freellmapi/docker-compose.yml -o docker-compose.yml \
      || { echo "compose 파일을 받을 수 없다 — $SCRIPT_DIR/docker-compose.yml 을 직접 복사할 것"; exit 1; }
  fi
fi

if [ ! -f .env ]; then
  echo "▸ .env 생성 — 암호화 키는 한 번만 만들고 절대 바꾸지 않는다"
  cat > .env <<EOF
ENCRYPTION_KEY=$(openssl rand -hex 32)
PORT=3001
HOST_BIND=127.0.0.1
EOF
  chmod 600 .env
else
  echo "▸ .env 가 이미 있다 — 그대로 사용한다 (암호화 키 유지)"
fi

echo "▸ 이미지 pull"
docker compose pull

echo "▸ 기동"
docker compose up -d

cat <<EOF

──────────────────────────────────────────────
설치 완료. 다음 단계:

  cd $INSTALL_DIR
  docker compose ps                # healthy 확인
  docker compose logs -f freellmapi

브라우저: http://localhost:3001
  1) 첫 관리자 계정 생성
  2) Keys 페이지에서 provider 키 등록 (Google · Groq · OpenRouter · Cerebras …)
  3) Fallback Chain 순서 조정
  4) Keys 페이지 헤더의 통합 API 키(freellmapi-…) 복사

다른 장비에서 접속하려면 .env 의 HOST_BIND=0.0.0.0 후 docker compose up -d
자세한 내용: https://github.com/Juser0/setup-instructions#1-freellmapi-docker-on-premise
──────────────────────────────────────────────
EOF
