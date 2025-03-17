# BIND DNS Server with RFC 2168 Dynamic Updates

This repository contains an example of a container image which runs the [BIND9
DNS server](https://www.isc.org/bind/) configured to serve a specific zone and
accept [RFC 2136 dynamic updates](https://www.rfc-editor.org/rfc/rfc2136) for
that zone. The zone name is configurable through an environment variable, as
are the other parameters needed for dynamic dns updates. BIND is also configured
to act as a recursive resolver for clients in private networks ([RFC1918](https://en.wikipedia.org/wiki/Private_network)).

The repository also contains an example [Zedcloud application](https://help.zededa.com/hc/en-us/articles/4440342005659-Edge-Application-Overview#h_01HMS85RTD1M1WQEMB8JKKEJH7)
that can be used to deploy and run the container as an [application instance](https://help.zededa.com/hc/en-us/articles/4440323343771-Edge-Application-Instance-Overview)
on an [edge-node](https://help.zededa.com/hc/en-us/articles/4440282818715-Edge-Node-Overview).

The example deployment is in the `./zedcloud_deployment/` directory and is
configured using [terraform](https://www.terraform.io/)/[tofu](https://opentofu.org/)
using the zedcloud terraform provider, e.g. [zedcloud / resources / application](https://registry.terraform.io/providers/zededa/zedcloud/latest/docs/resources/application).

## Features

- BIND 9 DNS server configured as an authoritative nameserver for a specific
  zone and as a recursive resolver for anything else for clients in private networks.
- Zone name configurable via an environment variable.
- Support for RFC 2136 dynamic updates with TSIG key authentication. Automatic
  generation of TSIG secret for secure updates.
- Optional volume mounting for persistent TSIG secret and persistent zone data.

## Usage

### Environment variables

- `ZONE_NAME`: The DNS zone to serve (default: `example.net`).
- `ZONE_TSIG_KEY`: The name of the TSIG key for dynamic updates (default: `dyn-update-key`).
- `ZONE_TSIG_SECRET`: The secret for the TSIG key (if not provided, one will be generated automatically).
- `LISTEN_ON`: A `;` separated list of IPv4 addresses on which BIND9 should listen
  on. The default is `any`.
- `UPSTREAM_RESOLVERS`: A `;` separated list of IPv4 addresses which BIND9 will
  use to do recursive resolution for anything outside it's own authoritative zone.
  If not specified then the nameservers from the containers `/etc/resolv.conf` will
  be used.

### Building and running with Docker

```bash
# Build the image
docker build -t bind-dns-server .

# Run the container with default zone (example.net)
docker run -d --name bind -p 53:53/udp -p 53:53/tcp bind-dns-server

# Run with a custom zone
docker run -d --name bind -p 53:53/udp -p 53:53/tcp \
  -e ZONE_NAME=test.example.com bind-dns-server
```

## Dynamic DNS Updates

The server is configured to accept dynamic updates for the configured zone
using TSIG key authentication. To perform dynamic updates, you'll need the
TSIG key and secret information. If both have been provided via environment
variables then those values will used. If the secret was not provided then
a new one will be generated at container start time. In both cases the info
is displayed in the container logs when it starts.

```bash
docker logs bind | head -n 14
```

Look for the section:
```
===== BIND DNS Server Configuration =====
Zone: example.com
TSIG Key Name: dyn-update-key
TSIG Key Secret: (your generated key will be here)
========================================
```

### Example Update

Use the provided `update-example.sh` script as a template, replacing the values with your actual TSIG key information:

```bash
chmod u+x rfc2136_update_example.sh

export TSIG_KEY="dyn-update-key";
export TSIG_SECRET="-_- the secret value \()/";
# Only needed if the zone is different than the default (example.net).
# export ZONE_NAME="test.example.com";

./rfc2136_update_example.sh add host1.example.net 192.168.1.13
#### or
./rfc2136_update_example.sh replace host1.example.net 192.168.1.13
```

Or manually using `nsupdate`:

```bash
nsupdate -y hmac-sha256:dyn-update-key:YOUR_TSIG_KEY_SECRET <<EOF
server 127.0.0.1
zone example.net
update add host1.example.net 3600 A 192.168.1.13
send
EOF
```

## Testing the DNS Server

You can verify that the DNS server is working correctly using `dig`:

```bash
# Query the server for the SOA record
dig @127.0.0.1 example.net SOA

# After adding a record with nsupdate, verify it
dig @127.0.0.1 host1.example.net A
```

## Security Considerations

- In production environments, you should provide a secure TSIG key rather than
  relying on the automatically generated one.
- Consider adding firewall rules to restrict which IP addresses can send updates
  to your DNS server.
- The container runs BIND as root by default; for enhanced security in production,
  consider modifying it to run as a non-root user.
