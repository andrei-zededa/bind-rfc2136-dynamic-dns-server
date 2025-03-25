#!/bin/bash

set -eu;
set -o pipefail;

ZONE_NAME="${ZONE_NAME:-example.net}";
ZONE_TSIG_KEY="${ZONE_TSIG_KEY:-dyn-update-key}";
ZONE_TSIG_SECRET="${ZONE_TSIG_SECRET:-}";

LISTEN_ON="${LISTEN_ON:-any}";
UPSTREAM_RESOLVERS="${UPSTREAM_RESOLVERS:-}";

tsig_conf_file="/etc/bind/dyn-update/dyn-update.key";

# Generate a new TSIG secret if one is not provided as an environment variable;
# also check if one was generated on a previous run of this container and saved
# in a mounted volume.
[ -z "$ZONE_TSIG_SECRET" ] && {
	if [ -f "$tsig_conf_file" ]; then
		echo "Re-using previously generated TSIG secret.";
	else
		echo "Generating a new TSIG secret ......";
		ZONE_TSIG_SECRET="$(head -c 16 /dev/urandom | base64)";
		echo "Generated TSIG secret: $ZONE_TSIG_SECRET";
	fi
}

# Create (or update) the key config file.
mkdir -p "$(dirname "$tsig_conf_file")";
cat > "$tsig_conf_file" <<-EOF
key "${ZONE_TSIG_KEY}" {
	algorithm hmac-sha256;
	secret "${ZONE_TSIG_SECRET}";
};
EOF

# Create the named.conf.local file with the zone definition.
cat > /etc/bind/named.conf.local <<-EOF
// Include the dynamic update key config file.
include "$tsig_conf_file";

// Zone definition for '${ZONE_NAME}'.
zone "${ZONE_NAME}" {
    type master;
    file "/etc/bind/zones/db.${ZONE_NAME}";
    allow-update { key "${ZONE_TSIG_KEY}"; };
    notify yes;
};
EOF

# Create the zone file from the template if it doesn't exist.
if [ -f "/etc/bind/zones/db.${ZONE_NAME}" ]; then
	echo "Zone file '${ZONE_NAME}' already exists.";
else
	echo "Creating a new zone file for '${ZONE_NAME}' ......";
	# Create a serial number based on the date (YYYYMMDDnn format).
	serial="$(date +%Y%m%d01)";

	mkdir -p "/etc/bind/zones";
	sed -E "s/__ZONE_NAME__/${ZONE_NAME}/g" "/etc/bind/zone.template"	\
		| sed "s/__SERIAL__/${serial}/g" > "/etc/bind/zones/db.${ZONE_NAME}";
fi

# If UPSTREAM_RESOLVERS is non-empty then use it, otherwise try and find the
# name-servers from /etc/resolv.conf .
if [ -z "$UPSTREAM_RESOLVERS" ]; then
	echo "UPSTREAM_RESOLVERS is empty, will try to use nameservers from /etc/resolv.conf ......";
	UPSTREAM_RESOLVERS="$(grep -E '^[[:space:]]*nameserver' "/etc/resolv.conf"	\
		| awk '{printf(" %s;", $2);}')";
	echo "It becomes UPSTREAM_RESOLVERS='$UPSTREAM_RESOLVERS'.";
else
	echo "Using UPSTREAM_RESOLVERS='$UPSTREAM_RESOLVERS'.";
fi

[ -n "$UPSTREAM_RESOLVERS" ] && {
	rgxp=";$";
	[[ "$UPSTREAM_RESOLVERS" =~ $rgxp ]] || {
		UPSTREAM_RESOLVERS="${UPSTREAM_RESOLVERS};";
	}
	sed -E "s|//[[:space:]]*__FORWARDERS__|forwarders { $UPSTREAM_RESOLVERS };|g"	\
		"/etc/bind/named.conf.options.template"		\
		> "/etc/bind/named.conf.options";
}

[ -n "$LISTEN_ON" ] && {
	rgxp=";$";
	[[ "$LISTEN_ON" =~ $rgxp ]] || {
		LISTEN_ON="${LISTEN_ON};";
	}
	if grep "__LISTEN_ON__" "/etc/bind/named.conf.options" >/dev/null; then
		# /etc/bind/named.conf.options is already replaced
		# by UPSTREAM_RESOLVERS handling.
		sed -E "s|//[[:space:]]*__LISTEN_ON__|listen-on { $LISTEN_ON };|g"	\
			"/etc/bind/named.conf.options"		\
			> "/etc/bind/named.conf.options.new";
		mv "/etc/bind/named.conf.options.new" "/etc/bind/named.conf.options";

	else
		# /etc/bind/named.conf.options not yet replaced, use
		# the template.
		sed -E "s|//[[:space:]]*__LISTEN_ON__|listen-on { $LISTEN_ON };|g"	\
			"/etc/bind/named.conf.options.template"		\
			> "/etc/bind/named.conf.options";
	fi
}

# Display important running information, including TSIG details.
echo "====== BIND9 DNS Server Configuration ======";
echo "ZONE: ${ZONE_NAME}";
echo "";
echo "TSIG Key Name: ${ZONE_TSIG_KEY}";
echo "TSIG Key Secret: ${ZONE_TSIG_SECRET}";
echo "";
echo "LISTEN_ON: ${LISTEN_ON}";
echo "UPSTREAM_RESOLVERS: ${UPSTREAM_RESOLVERS}";
echo "============================================";

# Check if there are any syntax errors in the configuration.
named-checkconf "/etc/bind/named.conf";

# Check the zone file
named-checkzone "${ZONE_NAME}" "/etc/bind/zones/db.${ZONE_NAME}";

# Evaluate any additional environment variables passed as a JSON file.
more_env_vars_file="/custom_config_env_vars.json";
[ -f "$more_env_vars_file" ] && {
        # Process the JSON file with safety measures for special characters.
	more_env_vars="$(jq -er -f <(cat <<-'JQPROGRAM'
		to_entries | .[] |
		# Check if key is a valid shell variable name (letters, numbers, underscore, not starting with a number)
		if (.key | test("^[a-zA-Z_][a-zA-Z0-9_]*$")) then
			# Handle different value types
			if (.value | type) == "string" then
				# Escape single quotes in string values
				"export \(.key)='\(.value | @sh)'"
			elif (.value | type) == "number" or (.value | type) == "boolean" then
				"export \(.key)=\(.value)"
			else
				# For arrays, objects and other complex types
				"export \(.key)='\(.value | tostring | @sh)'"
			end
		else
			# Skip invalid variable names and print warning
			"# WARNING: Skipping invalid variable name: \(.key)"
		end
		JQPROGRAM
		) "$more_env_vars_file" || true)";
	[ -n "$more_env_vars" ] && {
		echo "= Loading more environment variables from ${more_env_vars_file}: =";
		echo "$more_env_vars";
		source <(echo "$more_env_vars");
		echo "========================================================================";
	}
}

# Pass control to the CMD in the Dockerfile
exec "$@";
