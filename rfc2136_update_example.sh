#!/usr/bin/env bash

set -eu;
set -o pipefail;

_nsupdate="$(command -v nsupdate)" || echo "Can't find the nsupdate command, maybe the dig package needs to be installed.";

TSIG_KEY="${TSIG_KEY:?The TSIG_KEY env var must be set !}";
TSIG_SECRET="${TSIG_SECRET:?The TSIG_SECRET env var must be set !}";
ZONE_NAME="${ZONE_NAME:-example.net}";

SERVER_ADDR="${SERVER_ADDR:-127.0.0.1}";

op="${1:?Usage: $0 add|replace host ipv4_address}";
host="${2:?Usage: $0 add|replace host ipv4_address}";
addr="${3:?Usage: $0 add|replace host ipv4_address}";

[ "_$op" == "_replace" ] && {
	$_nsupdate -y "hmac-sha256:${TSIG_KEY}:${TSIG_SECRET}" <<-EOF
	server $SERVER_ADDR
	zone $ZONE_NAME
	update delete $host
	send
	EOF
}

$_nsupdate -y "hmac-sha256:${TSIG_KEY}:${TSIG_SECRET}" <<-EOF
server $SERVER_ADDR
zone $ZONE_NAME
update add $host 3600 A $addr
send
EOF
