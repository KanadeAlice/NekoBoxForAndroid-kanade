#!/bin/bash
set -e

source "buildScript/init/env.sh"
ENV_NB4A=1
source "buildScript/lib/core/get_source_env.sh"
pushd ..

####

if [ ! -d "sing-box" ]; then
  git clone --no-checkout https://github.com/MatsuriDayo/sing-box.git
fi
pushd sing-box
git checkout "$COMMIT_SING_BOX"
popd

# --- neko patch: REALITY client version spoof (fix Xray-core 26.3.27 minClientVer gate) ---
# Xray-core v26.7.11+ enforces default REALITY minClientVer=26.3.27; sing-box's reality
# client hardcodes ClientVer=1.8.1 and gets rejected. Bump it to 26.7.28 (>= 26.3.27).
# Refs: XTLS/Xray-core commit af7eb68028 ; MHSanaei/3x-ui#5922
REALITY_FILE="sing-box/common/tls/reality_client.go"
if [ -f "$REALITY_FILE" ]; then
  if ! grep -qF 'hello.SessionId[0] = 26' "$REALITY_FILE"; then
    sed -i \
      -e 's/hello\.SessionId\[0\] = 1$/hello.SessionId[0] = 26/' \
      -e 's/hello\.SessionId\[1\] = 8$/hello.SessionId[1] = 7/' \
      -e 's/hello\.SessionId\[2\] = 1$/hello.SessionId[2] = 28/' \
      "$REALITY_FILE"
  fi
  if grep -qF 'hello.SessionId[0] = 26' "$REALITY_FILE" && grep -qF 'hello.SessionId[1] = 7' "$REALITY_FILE" && grep -qF 'hello.SessionId[2] = 28' "$REALITY_FILE"; then
    echo ">> reality patch applied: ClientVer -> 26.7.28 (>= 26.3.27)"
  else
    echo ">> ERROR: reality patch failed to apply; upstream may have changed $REALITY_FILE" >&2
    exit 1
  fi
else
  echo ">> ERROR: $REALITY_FILE not found" >&2
  exit 1
fi
# --- end neko patch ---

# --- neko patch: boxapi RoutedFlow (adapter.ConnectionTracker gained RoutedFlow in 1.14) ---
ROUTEDFLOW_FILE="sing-box/boxapi/routedflow_neko.go"
if [ -f "sing-box/boxapi/v2ray_stats_service.go" ] && [ ! -f "$ROUTEDFLOW_FILE" ]; then
  cat > "$ROUTEDFLOW_FILE" <<'NEKO_EOF'
package boxapi

import (
	"context"

	"github.com/sagernet/sing-box/adapter"
	tun "github.com/sagernet/sing-tun"
)

func (s *SbStatsService) RoutedFlow(ctx context.Context, metadata adapter.InboundContext, matchedRule adapter.Rule, matchOutbound adapter.Outbound) tun.FlowTracker {
	return nil
}
NEKO_EOF
  echo ">> boxapi RoutedFlow patch applied"
fi
# --- end neko patch ---

####

if [ ! -d "libneko" ]; then
  git clone --no-checkout https://github.com/MatsuriDayo/libneko.git
fi
pushd libneko
git checkout "$COMMIT_LIBNEKO"
popd

####

popd
