locals {
  # We take the container image tag and trim any leading `v` to use it
  # for the 2 edge-app version fields. Although this is not strictly
  # necessary as the 2 edge-app version fields are freeform strings.
  image_version = replace(var.DOCKERHUB_IMAGE_LATEST_TAG, "/^v/", "")

  custom_config_base64 = filebase64("./edge_app_custom_config.txt")
}

# This defines an edge-app of type container that can be deployed on an
# edge-node by creating a per-edge-node edge-app-instance. The instance
# can be created either specifically per-edge-node or it can be created
# automatically for every edge-node that becomes part of a project with
# an app policy.
#
# The edge-app definition uses the container image defined in `images.tf`
# and also configures the following:
#   - Resources (no. vCPUs & RAM) that will be allocated to each instance.
#   - A "custom config" that allows setting all the environment variables
#     that the container image supports. The end result will be the same as
#     `docker run --env A=B`.
#   - An interface named `internet` (the name is for management purposes only,
#     doesn't actually translate to anything in the running container).
#   - A 2nd interface named `internal`. This interface has ACLs with a portmap
#     mapping the edge-node port `53` to the app port 53 (both UDP & TCP).
#     This is similar to running `docker run -p 53:53/udp -p 53:53/tcp`.
resource "zedcloud_application" "app_definition" {
  name  = "${var.DOCKERHUB_IMAGE_NAME}_app_definition"
  title = "${var.DOCKERHUB_IMAGE_NAME}_app_definition"

  networks    = 1
  origin_type = "ORIGIN_LOCAL"

  user_defined_version = local.image_version

  manifest {
    ac_kind             = "PodManifest"
    ac_version          = local.image_version
    app_type            = "APP_TYPE_CONTAINER"
    cpu_pinning_enabled = false
    deployment_type     = "DEPLOYMENT_TYPE_STAND_ALONE"
    enablevnc           = false
    name                = "${var.DOCKERHUB_IMAGE_NAME}_app_definition"
    vmmode              = "HV_PV"

    configuration {
      # https://help.zededa.com/hc/en-us/articles/4440323189403-Custom-Configuration-Edge-Application#01JF0TNWAFAAVRY5K7PJHYYP5Z
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
            for_each = var.CONTAINER_DEFAULT_ENV_VARS
            content {
              name       = variables.value.name
              default    = variables.value.default
              required   = variables.value.required
              label      = variables.value.label
              format     = variables.value.format
              encode     = variables.value.encode
              max_length = variables.value.max_length
            }
          }
        }
      }
    }

    desc {
      agreement_list  = {}
      app_category    = "APP_CATEGORY_UNSPECIFIED"
      category        = "APP_CATEGORY_DEVOPS"
      license_list    = {}
      logo            = {}
      screenshot_list = {}
    }

    images {
      cleartext   = true
      ignorepurge = false
      imageformat = "CONTAINER"
      imageid     = zedcloud_image.container_image.id
      imagename   = zedcloud_image.container_image.name
      maxsize     = "0"
      mountpath   = "/"
      preserve    = false
      readonly    = false
    }

    interfaces {
      directattach = false
      name         = "app_eth0"
      optional     = false
      privateip    = false

      acls {
        matches {
          type  = "ip"
          value = "0.0.0.0/0"
        }
      }
    }

    owner {
      email   = "support@zededa.com"
      user    = "Zededa Support"
      website = "help.zededa.com"
    }

    resources {
      name  = "resourceType"
      value = "Tiny"
    }
    resources {
      name  = "cpus"
      value = "1"
    }
    resources {
      name  = "memory"
      value = "524288.00"
    }
  }
}
