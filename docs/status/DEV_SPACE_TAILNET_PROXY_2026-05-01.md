# Dev-Space Tailnet Proxy

기준일: `2026-05-01`

## 목적

`dev-space` 관찰면은 현재
`dev-space.10.113.24.96.nip.io`
라는 lab 내부 VIP 호스트명으로는 정상 동작한다.

하지만 원격 tailnet 클라이언트는
`10.113.24.96` 대역으로 직접 라우팅되지 않기 때문에
동일 URL로 접근할 수 없다.

이번 문서는 `100.123.80.48` 호스트에서
reverse proxy를 띄워 tailnet 진입점을 따로 고정하는 절차를 정의한다.

## 확정된 진단 결과

- `seoy@100.123.80.48` 에서는 `http://10.113.24.96/` 연결 가능
- 같은 호스트에서 `Host: dev-space.10.113.24.96.nip.io` 로 요청 시 `200 OK`
- `devcom` 에서는 `10.113.24.96:80` 직접 접근이 타임아웃
- 따라서 문제는 앱/HTTPRoute가 아니라 tailnet 쪽 라우팅 부재다

## 선택한 방식

이번에는 subnet router 대신
`100.123.80.48` 위에 `nginx` reverse proxy를 별도 서비스로 둔다.

이 방식의 이유:

- 현재 필요한 대상이 `dev-space` 단일 HTTP 엔드포인트다
- `Host` 헤더를 프록시에서 강제로 고정할 수 있다
- tailnet 라우팅 정책을 당장 손대지 않아도 된다
- 장애 범위가 `dev-space` 단일 진입점으로 제한된다

## 배포 자산

- nginx 설정:
  `deploy/dev-space-tailnet-proxy/nginx.conf`
- systemd 유닛 템플릿:
  `deploy/dev-space-tailnet-proxy/dev-space-tailnet-proxy.service`
- 원격 설치 스크립트:
  `scripts/install-dev-space-tailnet-proxy.sh`

## 기대 진입점

기본 포트는 `8008` 이다.

- tailnet URL:
  `http://100.123.80.48:8008/`
- health check:
  `http://100.123.80.48:8008/healthz`

## 설치 절차

로컬 작업 디렉터리에서 아래를 실행한다.

```bash
cd /opt/go/src/github.com/HeaInSeo/batch-integration
./scripts/install-dev-space-tailnet-proxy.sh
```

기본값:

- 원격 대상: `seoy@100.123.80.48`
- upstream addr: `10.113.24.96`
- upstream host header: `dev-space.10.113.24.96.nip.io`
- listen port: `8008`
- Rocky/RHEL 계열에서 `nginx` 가 없으면 `dnf install -y nginx` 자동 시도
- SELinux 활성 시 `httpd_can_network_connect=on` 자동 적용

필요하면 환경변수로 바꾼다.

```bash
TAILNET_PROXY_PORT=28080 \
REMOTE_SSH_TARGET=seoy@100.123.80.48 \
./scripts/install-dev-space-tailnet-proxy.sh
```

## 검증

원격 호스트에서:

```bash
sudo systemctl status dev-space-tailnet-proxy --no-pager
curl -v http://127.0.0.1:8008/healthz
curl -v http://127.0.0.1:8008/
```

tailnet 클라이언트에서:

```bash
curl -v http://100.123.80.48:8008/
```

정상이라면 `dev-space observability` HTML이 반환돼야 한다.
