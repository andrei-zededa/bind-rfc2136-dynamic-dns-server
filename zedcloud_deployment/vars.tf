# The variables below can be set either as an environment variable in
# the `TF_VAR_ZEDEDA_CLOUD_URL="zedcloud...."` format, for example, or
# as a `-var="ZEDEDA_CLOUD_URL=zedcloud...."` CLI argument.

# Defined as a secret in the Github repo.
variable "ZEDEDA_CLOUD_URL" {
  description = "ZEDEDA CLOUD URL"
  sensitive   = true
  type        = string
}

# Defined as a secret in the Github repo.
variable "ZEDEDA_CLOUD_TOKEN" {
  description = "ZEDEDA CLOUD API TOKEN"
  sensitive   = true
  type        = string
}

# Defined as a variable in the Github repo.
variable "DOCKERHUB_USERNAME" {
  sensitive = false
  type      = string
  default   = "andreizededa"
}

# Defined as a variable in the Github repo.
variable "DOCKERHUB_IMAGE_NAME" {
  sensitive = false
  type      = string
  default   = "bind-rfc2136-dynamic-dns-server"
}

# Most likely this comes from the trigger for the GHA workflow that calls
# terraform. The corresponding `TF_VAR_DOCKERHUB_IMAGE_LATEST_TAG` environment
# variable should be set to override the `latest` default value below.
variable "DOCKERHUB_IMAGE_LATEST_TAG" {
  sensitive = false
  type      = string
  default   = "latest"
}

variable "PROJECT_NAME" {
  sensitive = false
  type      = string
  default   = "TEST_PROJECT_1001"
}

variable "EDGE_NODE_NAME" {
  sensitive = false
  type      = string
  default   = "TEST_NODE_1001"
}

variable "DNS_SERVER_IP_ADDR" {
  sensitive = false
  type      = string
  default   = "192.168.13.13"
}

variable "CONTAINER_DEFAULT_ENV_VARS" {
  description = "Configuration variables for BIND9 DNS server"
  type = list(object({
    name       = string
    default    = string
    required   = bool
    label      = string
    format     = string
    encode     = string
    max_length = string
    value      = string
  }))
  default = [
    {
      name       = "ZONE_NAME"
      default    = "example.net"
      required   = false
      label      = "The DNS zone to serve (default: `example.net`)."
      format     = "VARIABLE_FORMAT_TEXT"
      encode     = "FILE_ENCODING_UNSPECIFIED"
      max_length = "200"
      value      = ""
    },
    {
      name       = "ZONE_TSIG_KEY"
      default    = "dyn-update-key"
      required   = false
      label      = "The name of the TSIG key for dynamic updates (default: `dyn-update-key`)."
      format     = "VARIABLE_FORMAT_TEXT"
      encode     = "FILE_ENCODING_UNSPECIFIED"
      max_length = "200"
      value      = ""
    },
    {
      name       = "ZONE_TSIG_SECRET"
      default    = ""
      required   = false
      label      = "The secret for the TSIG key (if not provided, one will be generated automatically)."
      format     = "VARIABLE_FORMAT_TEXT"
      encode     = "FILE_ENCODING_UNSPECIFIED"
      max_length = "200"
      value      = ""
    },
    {
      name       = "LISTEN_ON"
      default    = "any"
      required   = false
      label      = "A `;` separated list of IPv4 addresses on which BIND9 should listen on. The default is `any`."
      format     = "VARIABLE_FORMAT_TEXT"
      encode     = "FILE_ENCODING_UNSPECIFIED"
      max_length = "200"
      value      = ""
    },
    {
      name       = "UPSTREAM_RESOLVERS"
      default    = ""
      required   = false
      label      = "A `;` separated list of IPv4 addresses which BIND9 will use to do recursive resolution for anything outside it's own authoritative zone. If not specified then the nameservers from the containers `/etc/resolv.conf` will be used."
      format     = "VARIABLE_FORMAT_TEXT"
      encode     = "FILE_ENCODING_UNSPECIFIED"
      max_length = "200"
      value      = ""
    }
  ]
}

# Define your override values.
locals {
  APP_INSTANCE_ENV_VARS_OVERRIDES = {
    "ZONE_NAME" = {
      value = "custom-domain.com"
    },
    "LISTEN_ON" = {
      value = var.DNS_SERVER_IP_ADDR
    },
    "UPSTREAM_RESOLVERS" = {
      value = "8.8.8.8;8.8.4.4"
    }
  }

  # Create a deep copy with overrides applied
  APP_INSTANCE_ENV_VARS = [
    for var in var.CONTAINER_DEFAULT_ENV_VARS : merge(var,
      # Only try to merge if there's an override for this variable.
      contains(keys(local.APP_INSTANCE_ENV_VARS_OVERRIDES), var.name)
      ? local.APP_INSTANCE_ENV_VARS_OVERRIDES[var.name]
      : {}
    )
  ]
}
