# setup-instructions

설치/기동 방법을 모은 문서. 각 항목은 같은 순서로 적는다.

1. **무엇을 설치하는가** — 대상, 요구사항, 어디에 올라가는가
2. **어떤 파일로 설치하는가** — 이 저장소의 setup 파일, 또는 원본 저장소
3. **설치/기동 명령** — 복사해서 그대로 붙여넣는 순서
4. **어디까지 켜졌는지 확인하는가** — 헬스체크·로그·API 호출
5. **운영** — 백업·업데이트·로그·장애 대응

상세 사양(환경변수 전체, API 규격, 화면 조작 등)은 **해당 경로의 README**로 연결한다.
이 문서에는 "설치해서 켜는 최소 절차"만 둔다.

---

## 1. freellmapi (Docker on-premise)

무료 LLM 제공자 34곳(Google · Groq · Cerebras · OpenRouter · Mistral · NVIDIA · HF …)의 무료 티어를
하나의 OpenAI 호환 `/v1` 엔드포인트로 묶어 주는 로컬 라우터.
키는 AES-256-GCM 으로 암호화해서 SQLite 에 저장하고, 라우터가 모델을 골라 실패하면 다음 제공자로 넘어간다.

| 항목 | 값 |
| --- | --- |
| 대상 | FreeLLMAPI (MIT) |
| 원본 저장소 | <https://github.com/tashfeenahmed/freellmapi> · <https://freellmapi.co> |
| 원본 문서 | [Install & deploy](https://github.com/tashfeenahmed/freellmapi/blob/main/docs/en/install/01-install.md) · [Docker 가이드](https://github.com/tashfeenahmed/freellmapi/blob/main/docker/README.md) · [전체 .env.example](https://github.com/tashfeenahmed/freellmapi/blob/main/.env.example) · [API 레퍼런스](https://github.com/tashfeenahmed/freellmapi/blob/main/docs/en/api/01-rest-api.md) |
| 이 저장소의 setup 파일 | [`freellmapi/setup.sh`](./freellmapi/setup.sh) · [`freellmapi/docker-compose.yml`](./freellmapi/docker-compose.yml) · [`freellmapi/.env.example`](./freellmapi/.env.example) |
| 요구사항 | Docker 24+ , Docker Compose v2, OpenSSL (암호화 키 생성용) |
| 올라가는 곳 | Docker 호스트 1대 (on-premise). 대시보드 + API 가 같은 포트(기본 3001)에서 나간다 |
| 데이터 | named volume `freellmapi-data` → 컨테이너 `/app/server/data` (SQLite) |
| 주의 | **단일 사용자·로컬 우선** 설계. 인터넷에 공개하지 않는다 |

### 1-1. 설치

소스 빌드가 필요 없으므로 compose 파일 하나와 환경 파일만 준비하면 된다.

```bash
./freellmapi/setup.sh              # 기본: ~/freellmapi
./freellmapi/setup.sh /srv/freellmapi
```

수동으로 하려면:

```bash
mkdir -p ~/freellmapi && cd ~/freellmapi

# 1) compose 파일 내려받기 (이 저장소의 setup 파일)
curl -fsSL https://raw.githubusercontent.com/Juser0/setup-instructions/main/freellmapi/docker-compose.yml -o docker-compose.yml

# 2) 환경 파일 — 암호화 키는 한 번만 만들고 절대 바꾸지 않는다
cat > .env <<EOF
ENCRYPTION_KEY=$(openssl rand -hex 32)
PORT=3001
HOST_BIND=127.0.0.1
EOF
chmod 600 .env

# 3) 기동
docker compose up -d
```

선택 환경변수(프록시 · 백업 · TRUST_PROXY 등)는 [`freellmapi/.env.example`](./freellmapi/.env.example) 를 참고해
필요한 것만 `.env` 에 추가한다. 전체 목록은 [원본 .env.example](https://github.com/tashfeenahmed/freellmapi/blob/main/.env.example).

- `HOST_BIND=127.0.0.1` 은 **이 머신에서만** 접속. 같은 네트워크의 다른 장비(폰·다른 서버)에서
  접속하려면 `HOST_BIND=0.0.0.0` 으로 바꾸고 `docker compose up -d` 를 한 번 더 실행한다.
  신뢰된 LAN 에서만. 인증은 통합 API 키 하나에만 걸려 있다.
- 이미지 자체를 먼저 당겨 두려면 `docker compose pull` 을 먼저 실행.

### 1-2. 첫 설정 (대시보드)

1. `http://<서버>:3001` 접속 → **첫 관리자 계정** 생성( 이메일 + 비밀번호 ).
   서버가 다른 장비에서 접근 가능하면, 서버 로그에 찍힌 1회용 setup code 를 요구한다(미claim 설치 탈취 방지).
2. **Keys** 페이지 → provider 키 등록(Google AI Studio, Groq, OpenRouter, Cerebras, Mistral, NVIDIA NIM, Hugging Face …).
   키는 암호화되어 저장되고, 요청 시에만 메모리에서 복호화된다.
3. **Fallback Chain** 페이지 → 라우팅 순서 정리. 429/5xx 가 나면 자동으로 다음 후보로 넘어간다.
4. **Keys 페이지 헤더**의 통합 API 키(`freellmapi-…`) 를 복사한다. 클라이언트에 쓰는 값은 **이 키 하나**다.

대시보드는 단일 사용자용이다. 여러 사람이 공유하면 원본 제공자 키가 서로 충돌한다.

### 1-3. 확인

```bash
docker compose ps                       # STATUS 가 healthy 면 정상
docker compose logs -f freellmapi       # 로그 실시간 (첫 setup code 도 여기서 나온다)

curl -fsS http://127.0.0.1:3001/api/ping

curl -s http://127.0.0.1:3001/v1/models \
  -H "Authorization: Bearer freellmapi-<통합키>"

curl -s http://127.0.0.1:3001/v1/chat/completions \
  -H "Authorization: Bearer freellmapi-<통합키>" \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"ping"}]}'
```

`/v1/models` 가 목록을 주고, `/v1/chat/completions` 가 한 번 왕복하면 설치는 끝난다.
`model` 은 `"auto"`(라우터 자동 선택) 또는 구체 모델 id 를 쓴다.

### 1-4. 운영

**백업** — SQLite 파일이 암호화 키와 짝을 이루므로 **볼륨째로** 백업한다.

```bash
# 수동
docker run --rm -v freellmapi-data:/data -v "$PWD":/backup alpine \
  tar czf /backup/freellmapi-data-$(date +%F).tgz -C /data .

# 자동(암호화 백업, 서버가 뜨면서 주기적으로 PUT)
#   .env: FREEAPI_DB_BACKUP_URL=https://backup.example.com/freellmapi.db.backup
#         FREEAPI_DB_BACKUP_KEY=<64자 hex>   # 생략 시 ENCRYPTION_KEY 재사용
#         FREEAPI_DB_BACKUP_TOKEN=<bearer>   # 백업 대상이 인증을 요구하면
```

`ENCRYPTION_KEY` 는 백업과 별개로, 어딘가에 안전하게 보관한다. 잃어버리면 provider key 를 복구할 수 없다.

**업데이트**

```bash
docker compose pull && docker compose up -d      # 볼륨과 .env 는 유지된다
docker image ls ghcr.io/tashfeenahmed/freellmapi  # 사용 가능한 태그 확인
```

롤백이 필요하면 compose 의 `image:` 를 특정 태그로 고정하고 다시 `up -d` 한다.

**대시보드에서 업데이트** — 설정 화면의 "Update now" 를 쓰려면 Watchtower sidecar 를 켠다.
docker.sock 을 마운트하므로 호스트 root 동급 권한이 된다. 필요 없으면 끄 둔다.

```bash
printf "WATCHTOWER_TOKEN=%s\n" "$(openssl rand -hex 32)" >> .env
docker compose --profile autoupdate up -d
```

**HTTPS 리버스 프록시** — 인터넷에 노출할 계획이면 앞에 Caddy/nginx 를 둔다.

- `TRUST_PROXY=1` → 프록시가 넘긴 `X-Forwarded-For` / `X-Forwarded-Proto` 를 신뢰해 실제 클라이언트 IP 를 기록한다.
- HTTPS 라우팅 헤더를 그대로 넘기면 CSP의 `upgrade-insecure-requests` 가 자동으로 붙는다.
- `DASHBOARD_ORIGINS=http://dashboard.example.com` → API 와 다른 호스트에서 대시보드를 열 때 필요.

**프록시가 필요한 환경** — 호스트의 프록시(Clash 등)를 경유해야 외부 provider 에 닿는 경우:

```bash
# .env
PROXY_URL=socks5h://host.docker.internal:7890
```

컨테이너 안에서 `127.0.0.1` 은 컨테이너 자신이다. 호스트를 가리키려면 `host.docker.internal` 을 쓴다
(compose 에 `extra_hosts` 로 이미 매핑돼 있다). 호스트 프록시는 loopback 밖에서도 받도록 열어야 한다(Clash 의 `allow-lan: true`).

### 1-5. 문제 해결

| 증상 | 원인 | 조치 |
| --- | --- | --- |
| 다른 기기에서 페이지가 멈춘다 | 포트가 `127.0.0.1` 에만 바인딩됨 | `.env` 의 `HOST_BIND=0.0.0.0` → `docker compose up -d` |
| 컨테이너에서만 외부 API 연결 실패 | 호스트 프록시를 컨테이너가 못 봄 | `PROXY_URL=socks5h://host.docker.internal:7890` + 프록시 `allow-lan` |
| IPv6 전용 호스트에서 전부 실패 | Docker bridge 가 IPv4 only | `/etc/docker/daemon.json` 에 `"ipv6": true`, `"ip6tables": true`, `fixed-cidr-v6` 추가 후 Docker 재시작 |
| `401` 이 계속 난다 | 통합 키가 다르거나 만료 | 대시보드 Keys 페이지의 통합 키 재확인 |
| 저장돼 있던 provider key 가 깨졌다 | `ENCRYPTION_KEY` 를 바꿨다 | **되돌릴 것.** 교체 절차는 [원본 문서](https://github.com/tashfeenahmed/freellmapi/blob/main/docs/en/install/01-install.md#rotating-the-encryption-key) 참고(컨테이너 안에서 `npm run rotate-encryption-key`) |
| 비밀번호를 잊었다 | 서버 로그의 reset code 만료(15분) | 로그인 화면 "Forgot password?" → 로그에서 reset code 확인 → 새 비밀번호 설정 |
| 이미지 pull 이 느리다 / 실패한다 | registry 지연 | `docker pull ghcr.io/tashfeenahmed/freellmapi:latest` 재시도. 사내 mirror 가 있으면 `daemon.json` 의 `registry-mirrors` 설정 |
| 볼륨이 안 보인다 | 컨테이너 안의 `/app/server/data` | `docker volume inspect freellmapi-data` |

### 1-6. 제거

```bash
cd ~/freellmapi
docker compose down -v          # -v 를 빼면 DB(볼륨)를 남긴다
docker image rm ghcr.io/tashfeenahmed/freellmapi:latest
rm -rf ~/freellmapi             # .env(암호화 키 포함)까지 지우려면
```

### 1-7. 참고

- 데스크톱 앱(macOS/Windows dmg·exe)·Android Termux 설치는 [원본 README](https://github.com/tashfeenahmed/freellmapi#readme) 참고. 이 문서는 on-premise 서버 기준이다.
- 원본 저장소를 그대로 클론해서 개발하려면 `docker compose up -d --build` (이미지 빌드) 또는 [로컬 개발](https://github.com/tashfeenahmed/freellmapi/blob/main/docs/en/install/01-install.md#local-development)(Node 20+).
- Free tier 는 제공자별로 요청 수·토큰 상한이 있다. 대시보드 분석 화면에서 제공자별 사용량을 확인한다.

---

## 규칙

- setup 파일(compose·스크립트·env 템플릿)은 **대상 이름 폴더** 아래에 두고, 이 README 에서 경로 링크로 연결한다.
  예: [`freellmapi/docker-compose.yml`](./freellmapi/docker-compose.yml) · [`freellmapi/setup.sh`](./freellmapi/setup.sh)
- 시크릿은 커밋하지 않는다. `.env.example` 만 올리고 실제 값은 `.env` 로 분리한다(`.env` 는 gitignore 대상).
- 대상이 바뀌면(버전 업그레이드, 배포 방식 변경) 이 문서와 대상 README 를 같이 고친다.
- 문서 한국어, 명령과 파일 경로는 원문 그대로.

## 라이선스

이 문서 저장소는 [MIT](./LICENSE) 입니다. 각 대상 프로젝트의 라이선스는 원본 저장소를 따른다.
