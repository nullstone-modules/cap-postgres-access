provider "restapi" {
  uri                  = coalesce(local.db_admin_func_url, "https://noop")
  write_returns_object = true

  aws_v4_signing {
    service           = "lambda"
    access_key_id     = try(local.db_admin_invoker["access_key"], null)
    secret_access_key = try(local.db_admin_invoker["secret_key"], null)
  }
}

resource "restapi_object" "database_owner" {
  count = local.db_admin_v5 ? 1 : 0

  path         = "/roles"
  id_attribute = "name"

  data = jsonencode({
    name        = local.database_name
    useExisting = true
    skipDestroy = true
  })
}

resource "restapi_object" "database" {
  count = local.db_admin_v5 ? 1 : 0

  path         = "/databases"
  id_attribute = "name"

  data = jsonencode({
    name        = local.database_name
    owner       = local.database_owner
    useExisting = true
    skipDestroy = true
  })

  depends_on = [restapi_object.database_owner]
}

resource "restapi_object" "role" {
  count = local.db_admin_v5 ? 1 : 0

  path         = "/roles"
  id_attribute = "name"

  data = jsonencode({
    name        = local.username
    password    = random_password.this.result
    useExisting = true
    skipDestroy = true
  })
}

resource "restapi_object" "role_member" {
  count = local.db_admin_v5 ? 1 : 0

  path         = "/roles/${local.database_owner}/members"
  id_attribute = "member"

  data = jsonencode({
    target      = local.database_owner
    member      = local.username
    useExisting = true
    skipDestroy = true
  })

  depends_on = [
    restapi_object.database_owner,
    restapi_object.role
  ]
}

resource "restapi_object" "schema_privileges" {
  count = local.db_admin_v5 ? 1 : 0

  path         = "/databases/${local.database_name}/schema_privileges"
  id_attribute = "role"

  data = jsonencode({
    database    = local.database_name
    role        = local.username
    skipDestroy = true
  })

  depends_on = [
    restapi_object.database,
    restapi_object.role
  ]
}

resource "restapi_object" "default_grants" {
  count = local.db_admin_v5 ? 1 : 0

  path         = "/roles/${local.username}/default_grants"
  id_attribute = "id"

  data = jsonencode({
    role        = local.username
    target      = local.database_owner
    database    = local.database_name
    skipDestroy = true
  })

  depends_on = [
    restapi_object.role,
    restapi_object.database,
    restapi_object.database_owner
  ]
}
