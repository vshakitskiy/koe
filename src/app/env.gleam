import envoy
import gleam/int
import gleam/result

pub type Env {
  Env(
    database_url: String,
    jwt_secret: String,
    secret_key_base: String,
    certificate_path: String,
    keyfile_path: String,
    port: Int,
  )
}

pub fn extract_env() -> Result(Env, String) {
  use database_url <- result.try(database_url())
  use jwt_secret <- result.try(jwt_secret())
  use secret_key_base <- result.try(secret_key_base())
  use certificate_path <- result.try(certificate_path())
  use keyfile_path <- result.try(keyfile_path())

  Ok(Env(
    database_url:,
    jwt_secret:,
    secret_key_base:,
    certificate_path:,
    keyfile_path:,
    port: port(),
  ))
}

pub fn database_url() -> Result(String, String) {
  envoy.get("DATABASE_URL")
  |> result.replace_error("DATABASE_URL not set")
}

pub fn jwt_secret() -> Result(String, String) {
  envoy.get("JWT_SECRET")
  |> result.replace_error("JWT_SECRET not set")
}

pub fn secret_key_base() -> Result(String, String) {
  envoy.get("SECRET_KEY_BASE")
  |> result.replace_error("SECRET_KEY_BASE not set")
}

pub fn certificate_path() -> Result(String, String) {
  envoy.get("CERTIFICATE_PATH")
  |> result.replace_error("CERTIFICATE_PATH not set")
}

pub fn keyfile_path() -> Result(String, String) {
  envoy.get("KEYFILE_PATH")
  |> result.replace_error("KEYFILE_PATH not set")
}

pub fn port() -> Int {
  envoy.get("PORT")
  |> result.map(int.parse)
  |> result.flatten()
  |> result.unwrap(8080)
}
