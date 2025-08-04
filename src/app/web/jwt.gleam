import gleam/dynamic/decode
import gleam/json as j
import gleam/result
import gleam/time/duration
import gleam/time/timestamp
import gwt

pub type Claims {
  Claims(user_id: Int)
}

pub fn new_claims(user_id: Int) -> Claims {
  Claims(user_id)
}

fn insert_claims(jwt_builder: gwt.JwtBuilder, payload: Claims) -> gwt.JwtBuilder {
  gwt.set_payload_claim(jwt_builder, "user_id", j.int(payload.user_id))
}

fn extract_claims(
  jwt: gwt.Jwt(gwt.Verified),
) -> Result(Claims, gwt.JwtDecodeError) {
  use user_id <- result.try(gwt.get_payload_claim(jwt, "user_id", decode.int))

  Ok(Claims(user_id))
}

pub fn sign_token(
  expires_after expires_after: duration.Duration,
  claims claims: Claims,
  secret secret: String,
) {
  let system_time = timestamp.system_time()
  let expiration_time = timestamp.add(system_time, expires_after)
  let expiration = timestamp.to_unix_seconds_and_nanoseconds(expiration_time).0

  gwt.new()
  |> gwt.set_issuer("koe")
  |> gwt.set_expiration(expiration)
  |> insert_claims(claims)
  |> gwt.to_signed_string(gwt.HS256, secret)
}

pub fn verify_token(
  jwt: String,
  secret: String,
) -> Result(Claims, gwt.JwtDecodeError) {
  case gwt.from_signed_string(jwt, secret) {
    Ok(verified_jwt) -> extract_claims(verified_jwt)
    Error(error) -> Error(error)
  }
}
