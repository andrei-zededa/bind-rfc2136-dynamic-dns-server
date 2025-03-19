terraform {
  required_providers {
    zedcloud = {
      source  = "zededa/zedcloud"
      version = "2.3.1-rc2"
    }
  }
}

provider "zedcloud" {
  zedcloud_url   = var.ZEDEDA_CLOUD_URL
  zedcloud_token = var.ZEDEDA_CLOUD_TOKEN
}
