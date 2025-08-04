import app/v1/users/sql
import app/web.{type Context, error_response, message_response}
import app/web/jwt
import argus
import gleam/bit_array
import gleam/bool
import gleam/dynamic/decode
import gleam/http
import gleam/json as j
import gleam/result.{try}
import gleam/time/duration
import pog
import wisp.{type Request, type Response}

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

    _, _ -> web.unknown_endpoint()
  }
}

// TODO: restrict creating test users
pub fn is_test_username(username: String) -> Bool {
  case bit_array.from_string(username) {
    <<"_user$":utf8, _:bits>> -> True
    _ -> False
  }
}

fn credentials_decoder() -> decode.Decoder(#(String, String)) {
  use username <- decode.field("username", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(#(username, password))
}

fn register(req: Request, ctx: Context) -> Response {
  use <- web.require_method(req, http.Post)
  use json <- web.require_json(req)

  use <- web.return_result()

  use #(username, password) <- try(
    decode.run(json, credentials_decoder())
    |> result.replace_error(web.invalid_body()),
  )

  use hashes <- try(
    argus.hasher()
    |> argus.algorithm(argus.Argon2id)
    |> argus.time_cost(3)
    |> argus.memory_cost(12_228)
    |> argus.parallelism(1)
    |> argus.hash_length(32)
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
  use <- web.require_method(req, http.Post)
  use json <- web.require_json(req)

  use <- web.return_result()

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

  let jwt =
    jwt.sign_token(
      expires_after: duration.hours(24),
      claims: jwt.new_claims(user.id),
      secret: ctx.jwt_secret,
    )

  web.message_response(200, "Login successful")
  |> wisp.set_cookie(req, "session", jwt, wisp.Signed, 60 * 60 * 24)
  |> Ok
}

fn session(req: Request, ctx: Context) -> Response {
  use <- web.require_method(req, http.Get)
  use claims <- web.auth_middleware(req, ctx)

  use <- web.return_result()

  use user <- try(case sql.find_user_by_id(ctx.conn, claims.user_id) {
    Ok(pog.Returned(count: 1, rows: [user])) -> Ok(user)
    Ok(pog.Returned(count: 0, rows: _)) ->
      Error(error_response(401, "Unauthorized"))

    Error(issue) -> Error(web.internal(issue))
    Ok(never) -> Error(web.internal(never))
  })

  j.object([#("id", j.int(user.id)), #("username", j.string(user.username))])
  |> j.to_string_tree()
  |> wisp.json_body(wisp.ok(), _)
  |> Ok
}

fn logout(req: Request) -> Response {
  use <- web.require_method(req, http.Post)

  message_response(200, "Logged out successfully")
  |> wisp.set_cookie(req, "session", "", wisp.Signed, 0)
}
