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

# --- neko patch: REALITY client version spoof (defeat Xray-core minClientVer gate) ---
# Xray-core v26.7.11+ enforces a REALITY minClientVer floor; when left blank it tracks the
# panel's current core version, so any fixed client version gets outrun on the next Xray update.
# sing-box hardcodes ClientVer=1.8.1; report the max 255.255.255 so the handshake passes ANY
# minClientVer floor, permanently. Refs: XTLS/Xray-core commit af7eb68028 ; MHSanaei/3x-ui#5922
REALITY_FILE="sing-box/common/tls/reality_client.go"
if [ -f "$REALITY_FILE" ]; then
  if ! grep -qF 'hello.SessionId[0] = 255' "$REALITY_FILE"; then
    sed -i \
      -e 's/hello\.SessionId\[0\] = 1$/hello.SessionId[0] = 255/' \
      -e 's/hello\.SessionId\[1\] = 8$/hello.SessionId[1] = 255/' \
      -e 's/hello\.SessionId\[2\] = 1$/hello.SessionId[2] = 255/' \
      "$REALITY_FILE"
  fi
  if grep -qF 'hello.SessionId[0] = 255' "$REALITY_FILE" && grep -qF 'hello.SessionId[1] = 255' "$REALITY_FILE" && grep -qF 'hello.SessionId[2] = 255' "$REALITY_FILE"; then
    echo ">> reality patch applied: ClientVer -> 255.255.255 (passes any minClientVer)"
  else
    echo ">> ERROR: reality patch failed to apply; upstream may have changed $REALITY_FILE" >&2
    exit 1
  fi
else
  echo ">> ERROR: $REALITY_FILE not found" >&2
  exit 1
fi
# --- end neko patch ---

# --- neko patch: REALITY post-quantum X25519MLKEM768 (Xray-core >= v26.9 REQUIRES it) ---
# Modern Xray REALITY servers reject any ClientHello lacking an X25519MLKEM768 key share
# (-> "reality verification failed"). Upstream sing-box deliberately STRIPS it, so this
# UNDOES that strip and derives auth from Ecdhe??MlkemEcdhe, mirroring Xray-core's UClient.
# Do NOT re-enable the strip when syncing upstream, or REALITY breaks against current Xray.
if [ -f "$REALITY_FILE" ]; then
  if ! grep -qF 'keyShareKeys.MlkemEcdhe' "$REALITY_FILE"; then
    sed -i \
      -e 's/return curveID != utls.X25519MLKEM768/return true/' \
      -e 's/return share.Group != utls.X25519MLKEM768/return true/' \
      -e 's|ecdheKey := keyShareKeys.Ecdhe|ecdheKey := keyShareKeys.Ecdhe\n\tif ecdheKey == nil {\n\t\tecdheKey = keyShareKeys.MlkemEcdhe\n\t}|' \
      "$REALITY_FILE"
  fi
  if grep -qF 'keyShareKeys.MlkemEcdhe' "$REALITY_FILE" && ! grep -qF 'return curveID != utls.X25519MLKEM768' "$REALITY_FILE"; then
    echo ">> reality MLKEM patch applied: X25519MLKEM768 kept; auth via Ecdhe??MlkemEcdhe"
  else
    echo ">> ERROR: reality MLKEM patch failed to apply; upstream may have changed $REALITY_FILE" >&2
    exit 1
  fi
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
