resource "zedcloud_network_instance" "NI_INTERNET" {
  name      = "ni_internet_on_${data.zedcloud_edgenode.EDGE_NODE.name}"
  title     = "TF created instance of ni_internet for ${data.zedcloud_edgenode.EDGE_NODE.name}"
  kind      = "NETWORK_INSTANCE_KIND_LOCAL"
  type      = "NETWORK_INSTANCE_DHCP_TYPE_V4"
  device_id = data.zedcloud_edgenode.EDGE_NODE.id

  # `uplink` is the most common configuration or a value that must match the
  # edge-node interface name which is set the same as the "logical label" in
  # the model, could be `eth0` for example.
  port = "uplink"

  # The edge-application-instance (a specific interface of that instance) will
  # be connected to this network-instance by matching on a tag.
  tags = {
    ni_internet = "true"
  }
}

resource "zedcloud_network_instance" "NI_INTERNAL" {
  name  = "ni_internal_on_${data.zedcloud_edgenode.EDGE_NODE.name}"
  title = "TF created instance of ni_internal for ${data.zedcloud_edgenode.EDGE_NODE.name}"
  kind  = "NETWORK_INSTANCE_KIND_LOCAL"
  type  = "NETWORK_INSTANCE_DHCP_TYPE_V4"
  # kind  = "NETWORK_INSTANCE_KIND_SWITCH"
  # type  = "NETWORK_INSTANCE_DHCP_TYPE_UNSPECIFIED"
  device_id = data.zedcloud_edgenode.EDGE_NODE.id

  # Must match the edge-node interface name which is connected to the "INTERNAL
  # NETWORK" where we want the edge-app-instance to be available. The edge-node
  # interface name is the same as the "logical label" in the model, could be
  # `eth2` for example.
  port = "eth1"

  ip {
    subnet  = "192.168.13.0/24"
    gateway = "192.168.13.1"

    dns = var.DNS_SERVER_IP_ADDR != "" ? [var.DNS_SERVER_IP_ADDR] : ["192.168.13.1"]

    dhcp_range {
      start = "192.168.13.128"
      end   = "192.168.13.254"
    }
  }

  # The edge-application-instance (a specific interface of that instance) will
  # be connected to this network-instance by matching on a tag.
  tags = {
    ni_internal = "true"
  }
}

resource "zedcloud_application_instance" "APP_INSTANCE" {
  # We need to specifically add this dependencies due to the fact that the
  # edge-app-instance matches the network-instances through their tags.
  # Terraform cannot "see" this dependencies and would result in an error on
  # destroy because of ordering of operations.
  depends_on = [
    zedcloud_network_instance.NI_INTERNET,
    zedcloud_network_instance.NI_INTERNAL
  ]

  name      = "${data.zedcloud_project.PROJECT.name}__${data.zedcloud_edgenode.EDGE_NODE.name}__${zedcloud_application.app_definition.name}"
  title     = "TF created instance of ${zedcloud_application.app_definition.name} for ${data.zedcloud_edgenode.EDGE_NODE.name}"
  device_id = data.zedcloud_edgenode.EDGE_NODE.id
  app_id    = zedcloud_application.app_definition.id
  app_type  = zedcloud_application.app_definition.manifest[0].app_type

  activate = true

  logs {
    access = true
  }

  custom_config {
    add                  = true
    allow_storage_resize = false
    field_delimiter      = "####"
    name                 = "config01"
    override             = false
    # ❯ cat edge_app_custom_config.txt | base64
    # I2Nsb3VkLWNvbmZpZwpydW5jbWQ6CiAgLSBaT05FX05BTUU9IyMjI1pPTkVfTkFNRSMjIyMKICAt
    # ......
    template = local.custom_config_base64

    variable_groups {
      name     = "Default Group 1"
      required = true

      dynamic "variables" {
        for_each = local.APP_INSTANCE_ENV_VARS
        content {
          name       = variables.value.name
          default    = variables.value.default
          required   = variables.value.required
          label      = variables.value.label
          format     = variables.value.format
          encode     = variables.value.encode
          max_length = variables.value.max_length
          value      = variables.value.value
        }
      }
    }
  }

  manifest_info {
    transition_action = "INSTANCE_TA_NONE"
  }

  vminfo {
    cpus = 1
    mode = zedcloud_application.app_definition.manifest[0].vmmode
    vnc  = false
  }

  drives {
    cleartext = true
    mountpath = "/"
    imagename = zedcloud_image.container_image.name
    maxsize   = "0"
    preserve  = false
    readonly  = false
    drvtype   = ""
    target    = ""
  }

  interfaces {
    intfname    = zedcloud_application.app_definition.manifest[0].interfaces[0].name
    intforder   = 1
    privateip   = false
    netinstname = ""
    netinsttag = {
      ni_internet = "true"
    }
  }

  interfaces {
    intfname    = zedcloud_application.app_definition.manifest[0].interfaces[1].name
    intforder   = 2
    privateip   = false
    ipaddr      = var.DNS_SERVER_IP_ADDR != "" ? var.DNS_SERVER_IP_ADDR : ""
    netinstname = ""
    netinsttag = {
      ni_internal = "true"
    }
  }
}
