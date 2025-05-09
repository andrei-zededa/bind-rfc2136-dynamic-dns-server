data "zedcloud_network_instance" "NI_INTERNET" {
  name      = "PG-INTERNET-SESTHIT1-EVE121"
  title     = "PG-INTERNET-SESTHIT1-EVE121"
  kind      = "NETWORK_INSTANCE_KIND_SWITCH"
  device_id = data.zedcloud_edgenode.EDGE_NODE.id
}

resource "zedcloud_application_instance" "APP_INSTANCE" {
  # We need to specifically add this dependencies due to the fact that the
  # edge-app-instance matches the network-instances through their tags.
  # Terraform cannot "see" this dependencies and would result in an error on
  # destroy because of ordering of operations.
  depends_on = [
    data.zedcloud_network_instance.NI_INTERNET
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
    netinstname = data.zedcloud_network_instance.NI_INTERNET.name
  }
}
