#!/usr/bin/env bash

set -eu;
set -o pipefail;

_nsupdate="$(command -v nsupdate)";

TSIG_KEY="${TSIG_KEY:?The TSIG_KEY env var must be set !}";
TSIG_SECRET="${TSIG_SECRET:?The TSIG_SECRET env var must be set !}";
ZONE_NAME="${ZONE_NAME:-example.net}";

op="${1:?Usage: $0 add|replace host ipv4_address}";
host="${2:?Usage: $0 add|replace host ipv4_address}";
addr="${3:?Usage: $0 add|replace host ipv4_address}";

[ "_$op" == "_replace" ] && {
	$_nsupdate -y "hmac-sha256:${TSIG_KEY}:${TSIG_SECRET}" <<-EOF
	server 127.0.0.1
	zone example.net
	update delete $host
	send
	EOF
}

$_nsupdate -y "hmac-sha256:${TSIG_KEY}:${TSIG_SECRET}" <<-EOF
server 127.0.0.1
zone example.net
update add $host 3600 A $addr
send
EOF
