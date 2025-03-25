FROM ubuntu:24.04

# Install the BIND DNS server and related tools.
RUN apt-get update && \
    apt-get install -y bind9 bind9-utils dnsutils jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create necessary directories.
RUN mkdir -p /etc/bind/zones && mkdir -p /etc/bind/dyn-update

# Copy configuration files.
COPY named.conf.options /etc/bind/
COPY named.conf.options.template /etc/bind/
COPY named.conf.local /etc/bind/
COPY zone.template /etc/bind/

# Add the entrypoint script.
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

# Expose DNS ports.
EXPOSE 53/tcp 53/udp

# Environment variables.
ENV ZONE_NAME="example.net"
ENV ZONE_FILE="/etc/bind/zones/db.$ZONE_NAME"
ENV ZONE_TSIG_KEY="dyn-update-key"
ENV ZONE_TSIG_SECRET=""
ENV LISTEN_ON="any"
ENV UPSTREAM_RESOLVERS=""

# Set entrypoint.
ENTRYPOINT ["/entrypoint.sh"]

# Default command to run BIND.
CMD ["named", "-g", "-c", "/etc/bind/named.conf"]
