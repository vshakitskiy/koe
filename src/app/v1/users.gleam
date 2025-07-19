import app/v1/users/sql
import app/web.{type Context, error_response, message_response}
import argus
import envoy
import gleam/bool
import gleam/dynamic/decode
import gleam/http
import gleam/json as j
import gleam/result.{try}
import gleam/time/duration
import gleam/time/timestamp
import gwt
import pog
import wisp.{type Request, type Response}

fn credentials_decoder() -> decode.Decoder(#(String, String)) {
  use username <- decode.field("username", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(#(username, password))
}

fn hasher() -> argus.Hasher {
  argus.hasher()
  |> argus.algorithm(argus.Argon2id)
  |> argus.time_cost(3)
  |> argus.memory_cost(12_228)
  |> argus.parallelism(1)
  |> argus.hash_length(32)
}

pub fn handle_auth(
  req: Request,
  ctx: Context,
  segments: List(String),
) -> Response {
  case req.method, segments {
    http.Post, ["register"] -> register(req, ctx)
    http.Post, ["login"] -> login(req, ctx)
    http.Get, ["session"] -> session(req, ctx)
    http.Post, ["logout"] -> logout(req)

    _, ["register"] | _, ["login"] | _, ["logout"] ->
      web.method_not_allowed([http.Post])
    _, ["session"] -> web.method_not_allowed([http.Get])
    _, _ -> web.unknown_endpoint()
  }
}

fn register(req: Request, ctx: Context) -> Response {
  use json <- web.require_json(req)

  use <- web.wrap_handler()

  use #(username, password) <- try(
    decode.run(json, credentials_decoder())
    |> result.replace_error(web.invalid_body()),
  )

  use hashes <- try(
    hasher()
    |> argus.hash(password, argus.gen_salt())
    |> result.map_error(web.internal),
  )

  case sql.create_user(ctx.conn, username, hashes.encoded_hash) {
    Ok(pog.Returned(count: 1, rows: _)) ->
      Ok(message_response(201, "User created successfully"))
    Error(pog.ConstraintViolated(_, _, _)) ->
      Error(error_response(409, "Username already taken"))

    Error(issue) -> Error(web.internal(issue))
    Ok(never) -> Error(web.internal(never))
  }
}

fn login(req: Request, ctx: Context) -> Response {
  use json <- web.require_json(req)

  use <- web.wrap_handler()

  use #(username, password) <- try(
    decode.run(json, credentials_decoder())
    |> result.replace_error(web.invalid_body()),
  )

  use user <- try(case sql.find_user_by_username(ctx.conn, username) {
    Ok(pog.Returned(count: 1, rows: [user])) -> Ok(user)
    Ok(pog.Returned(count: 0, rows: _)) ->
      Error(error_response(401, "Invalid username or password"))

    Ok(never) -> Error(web.internal(never))
    Error(issue) -> Error(web.internal(issue))
  })

  use verified <- try(
    argus.verify(user.password_hash, password)
    |> result.map_error(web.internal),
  )

  use <- bool.lazy_guard(when: !verified, return: fn() {
    Error(error_response(401, "Invalid username or password"))
  })

  let system_time = timestamp.system_time()
  let expiration_time = timestamp.add(system_time, duration.hours(24))
  let expiration = timestamp.to_unix_seconds_and_nanoseconds(expiration_time).0

  let assert Ok(secret) = envoy.get("JWT_SECRET")
  let signed_jwt =
    gwt.new()
    |> gwt.set_subject("koe")
    |> gwt.set_audience("koechatter")
    |> gwt.set_expiration(expiration)
    |> gwt.set_payload_claim("user_id", j.int(user.id))
    |> gwt.to_signed_string(gwt.HS256, secret)

  let resp =
    web.message_response(200, "Login successful")
    |> wisp.set_cookie(req, "session", signed_jwt, wisp.Signed, 60 * 60 * 24)

  Ok(resp)
}

fn session(req: Request, ctx: Context) -> Response {
  use user_id <- web.auth_middleware(req)
  use <- web.wrap_handler()

  use user <- try(case sql.find_user_by_id(ctx.conn, user_id) {
    Ok(pog.Returned(count: 1, rows: [user])) -> Ok(user)
    Ok(pog.Returned(count: 0, rows: _)) ->
      Error(error_response(401, "Unauthorized"))

    Ok(never) -> Error(web.internal(never))
    Error(issue) -> Error(web.internal(issue))
  })

  Ok(
    j.object([#("id", j.int(user.id)), #("username", j.string(user.username))])
    |> j.to_string_tree()
    |> wisp.json_body(wisp.ok(), _),
  )
}

fn logout(req: Request) -> Response {
  message_response(200, "Logout successful")
  |> wisp.set_cookie(req, "session", "", wisp.Signed, 0)
}
