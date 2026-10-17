#!/usr/bin/env bash
# These guarantees are enforced by the Move compiler, so runtime abort tests
# cannot cover them. Compile hostile modules in a disposable package copy.
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
probe_root=$(mktemp -d)
trap 'rm -rf "$probe_root"' EXIT
for package in minehaul_core minehaul_armature; do
  mkdir -p "$probe_root/packages/$package"
  cp "$repo_root/packages/$package/Move.toml" "$probe_root/packages/$package/"
  cp -R "$repo_root/packages/$package/sources" "$probe_root/packages/$package/"
  if [[ -f "$repo_root/packages/$package/Move.lock" ]]; then
    cp "$repo_root/packages/$package/Move.lock" "$probe_root/packages/$package/"
  fi
done
probe_file="$probe_root/packages/minehaul_armature/sources/security_probe.move"
check_rejected() {
  local name="$1" expected="$2"
  if sui move build --path "$probe_root/packages/minehaul_armature" -e testnet > "$probe_root/build.log" 2>&1; then
    echo "FAIL: $name compiled successfully" >&2
    exit 1
  fi
  if ! grep -q "$expected" "$probe_root/build.log"; then
    cat "$probe_root/build.log" >&2
    echo "FAIL: $name failed for an unexpected reason" >&2
    exit 1
  fi
  echo "PASS: $name rejected by compiler"
}
cat > "$probe_file" <<'MOVE'
module minehaul_armature::security_probe;
use std::internal;
use minehaul_armature::list_haul_action::ListHaulAction;
public fun forge() { let _permit = internal::permit<ListHaulAction>(); }
MOVE
check_rejected 'foreign handler permit' 'E02011'
cat > "$probe_file" <<'MOVE'
module minehaul_armature::security_probe;
use minehaul_core::witnesses::DeliveryRequest;
public fun forget(request: DeliveryRequest) { }
MOVE
check_rejected 'discarded delivery obligation' 'E06001'
cat > "$probe_file" <<'MOVE'
module minehaul_armature::security_probe;
use minehaul_core::witnesses::VerifiedDelivery;
public fun forget(proof: VerifiedDelivery) { }
MOVE
check_rejected 'discarded delivery proof' 'E06001'
