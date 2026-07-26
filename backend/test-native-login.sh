#!/usr/bin/env bash
# 네이티브 카카오 로그인(/api/auth/kakao/native) 엔드투엔드 테스트 자동화.
# "인가 코드를 브라우저에서 받아 복사하는 것"만 사람이 하고, 그 뒤(토큰 교환 → 네이티브 로그인 호출 →
# 세션 유지 확인)는 전부 스크립트가 처리함 — redirect_uri/client_id/secret을 매번 손으로 다시 타이핑하다가
# 두 curl 사이에서 값이 어긋나는 실수를 구조적으로 없애기 위해 변수 하나로 통일해서 재사용함
set -uo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
# 카카오 콘솔에 이미 테스트용으로 등록해둔 redirect_uri (실제 서버가 이 경로를 처리할 필요는 없음 —
# 인가 코드만 URL에 담겨 오면 되므로 브라우저가 "연결할 수 없음"을 띄워도 정상)
REDIRECT_URI="${REDIRECT_URI:-http://localhost:8080/native-test-callback}"
SECRET_FILE="$(cd "$(dirname "$0")" && pwd)/src/main/resources/application-secret.properties"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
info() { echo -e "${YELLOW}$1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }

# --- 0. 사전 점검 ---
[ -f "$SECRET_FILE" ] || fail "$SECRET_FILE 을 찾을 수 없습니다. backend/ 안에서 실행했는지 확인하세요."

CLIENT_ID=$(grep -E '^kakao\.client-id=' "$SECRET_FILE" | tail -1 | cut -d'=' -f2- | tr -d '[:space:]')
CLIENT_SECRET=$(grep -E '^kakao\.client-secret=' "$SECRET_FILE" | tail -1 | cut -d'=' -f2- | tr -d '[:space:]')

[ -n "$CLIENT_ID" ] || fail "application-secret.properties에서 kakao.client-id를 못 찾았습니다. 키 이름을 확인하세요."
[ -n "$CLIENT_SECRET" ] || fail "application-secret.properties에서 kakao.client-secret을 못 찾았습니다. 키 이름을 확인하세요."
ok "REST API 키/시크릿 읽음 (client_id=${CLIENT_ID:0:6}...)"

if ! curl -s -o /dev/null --max-time 3 "$BASE_URL/api/auth/me"; then
  fail "$BASE_URL 에 연결할 수 없습니다. IntelliJ에서 백엔드(BackendApplication)를 실행했는지 확인하세요."
fi
ok "백엔드 응답 확인 ($BASE_URL)"

COOKIE_JAR="$(mktemp -t native-login-cookies)"
RESPONSE_FILE="$(mktemp -t native-login-response)"
trap 'rm -f "$COOKIE_JAR" "$RESPONSE_FILE"' EXIT

# --- 1. 인가 코드 받기 (여기만 사람이 함) ---
AUTH_URL="https://kauth.kakao.com/oauth/authorize?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&response_type=code"
echo
info "1) 아래 주소에서 카카오 로그인/동의를 완료하세요 (자동으로 브라우저를 엽니다):"
echo "   $AUTH_URL"
open "$AUTH_URL" 2>/dev/null || true
echo
info "   로그인 후 이동하는 주소(브라우저가 '연결할 수 없음' 에러를 보여줘도 정상입니다)의"
info "   ?code= 뒤에 있는 값만 복사해서 아래에 붙여넣으세요."
echo
read -rp "code= " RAW_CODE

# 방어: "code=xxx&state=yyy" 처럼 쿼리스트링째로 붙여넣거나 앞뒤 공백이 섞이는 실수 보정
CODE="${RAW_CODE#code=}"
CODE="${CODE%%&*}"
CODE="$(echo -n "$CODE" | tr -d '[:space:]')"
[ -n "$CODE" ] || fail "code 값이 비어 있습니다."
ok "code 입력 받음 (길이 ${#CODE}자)"

# --- 2. 토큰 교환 ---
echo
info "2) 인가 코드를 액세스 토큰으로 교환 중..."
TOKEN_RESPONSE=$(curl -s -X POST https://kauth.kakao.com/oauth/token \
  -d "grant_type=authorization_code" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "redirect_uri=${REDIRECT_URI}" \
  -d "code=${CODE}")

if echo "$TOKEN_RESPONSE" | grep -q '"error"'; then
  echo "   응답: $TOKEN_RESPONSE"
  if echo "$TOKEN_RESPONSE" | grep -qi 'redirect'; then
    HINT="redirect_uri 불일치 가능성 — 카카오 콘솔에 등록된 redirect_uri와 스크립트가 쓴 값($REDIRECT_URI)이 정확히 같은 문자열인지 확인하세요."
  elif echo "$TOKEN_RESPONSE" | grep -qi 'client_secret\|invalid_client'; then
    HINT="client_secret이 틀렸거나, 카카오 콘솔의 'Client Secret 활성화 상태'와 SecurityConfig의 client-authentication-method(client_secret_post) 설정이 안 맞을 수 있습니다."
  elif echo "$TOKEN_RESPONSE" | grep -qi 'invalid_grant\|expired\|already'; then
    HINT="인가 코드가 만료됐거나 이미 사용된 코드일 수 있습니다(1회용, 유효시간 짧음) — 1번부터 새로 받아서 바로 이어서 진행하세요."
  else
    HINT="위 응답 메시지를 참고하세요."
  fi
  fail "토큰 교환 실패: $HINT"
fi

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
[ -n "$ACCESS_TOKEN" ] || fail "토큰 교환 응답에서 access_token을 못 찾았습니다. 원본 응답: $TOKEN_RESPONSE"
ok "액세스 토큰 발급 성공 (앞 10자: ${ACCESS_TOKEN:0:10}...)"

# --- 3. 네이티브 로그인 엔드포인트 호출 ---
echo
info "3) $BASE_URL/api/auth/kakao/native 호출 중..."
LOGIN_HTTP_CODE=$(curl -s -o "$RESPONSE_FILE" -w "%{http_code}" \
  -X POST "$BASE_URL/api/auth/kakao/native" \
  -H "Content-Type: application/json" \
  -c "$COOKIE_JAR" \
  -d "{\"accessToken\":\"${ACCESS_TOKEN}\"}")
LOGIN_BODY=$(cat "$RESPONSE_FILE")

if [ "$LOGIN_HTTP_CODE" != "200" ]; then
  fail "네이티브 로그인 실패 (HTTP $LOGIN_HTTP_CODE): $LOGIN_BODY — IntelliJ Run 콘솔의 NativeKakaoAuthService WARN 로그에서 구체적 원인(카카오 응답)을 확인하세요."
fi
ok "네이티브 로그인 성공: $LOGIN_BODY"

# --- 4. 세션 유지 확인 ---
echo
info "4) 세션 유지 확인 중 (/api/auth/me)..."
ME_RESPONSE=$(curl -s -b "$COOKIE_JAR" "$BASE_URL/api/auth/me")
if echo "$ME_RESPONSE" | grep -q '"loggedIn":true'; then
  ok "세션 정상 유지됨: $ME_RESPONSE"
else
  fail "세션이 유지되지 않음: $ME_RESPONSE — NativeKakaoAuthService.establishSession()의 SecurityContext 저장 로직을 확인하세요."
fi

echo
ok "전체 테스트 통과!"
