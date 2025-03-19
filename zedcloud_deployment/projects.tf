data "zedcloud_project" "PROJECT" {
  name  = var.PROJECT_NAME
  title = var.PROJECT_NAME
  type  = "TAG_TYPE_PROJECT"
}
