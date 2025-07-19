import app/db
import app/router
import app/v1/users/sql
import app/web.{type Context, Context}
import app_test.{
  ensure_body, ensure_error, ensure_message, should_be_valid_resp,
  shutdown_context,
}
import envoy
import gleam/bit_array
import gleam/dict
import gleam/dynamic/decode
import gleam/http/response
import gleam/json as j
import gwt
import pog
import wisp
import wisp/testing

const test_username = "test_user"

const test_password = "Pa$$w0rD"

const test_credentials = #(test_username, test_password)

fn create_user_req(ctx: Context, creds: #(String, String), expected_status: Int) {
  let body =
    j.object([
      #("username", j.string(creds.0)),
      #("password", j.string(creds.1)),
    ])

  let req = testing.post_json("/api/v1/auth/register", [], body)
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, expected_status)

  case expected_status {
    201 -> ensure_message(resp, "User created successfully")
    409 -> ensure_error(resp, "Username already taken")
    500 -> ensure_error(resp, "Something went wrong, try again later")
    _ -> panic as "Expected 201 or 409 for expected_status argument"
  }
}

fn clear_user(conn: pog.Connection, username: String) {
  let assert Ok(_) = sql.delete_user_by_username(conn, username)
  Nil
}

pub fn include_user(
  ctx: Context,
  creds: #(String, String),
  handle_test: fn() -> Nil,
) {
  clear_user(ctx.conn, creds.0)
  create_user_req(ctx, creds, 201)
  handle_test()
  clear_user(ctx.conn, creds.0)
}

pub fn include_user_authorized(
  ctx: Context,
  creds: #(String, String),
  handle_test: fn(String) -> Nil,
) {
  use <- include_user(ctx, creds)

  let body =
    j.object([
      #("username", j.string(test_username)),
      #("password", j.string(test_password)),
    ])
  let req = testing.post_json("/api/v1/auth/login", [], body)
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 200)
  ensure_message(resp, "Login successful")

  let assert [#(_, signed_session), ..] = response.get_cookies(resp)

  verify_signed_session(req, signed_session)
  |> handle_test()
}

pub fn verify_signed_session(
  req: wisp.Request,
  signed_session: String,
) -> String {
  let assert Ok(session_bitarray) =
    wisp.verify_signed_message(req, signed_session)
  let assert Ok(session) = bit_array.to_string(session_bitarray)

  session
}

pub fn payload_from_session(session: String) -> Int {
  let assert Ok(secret) = envoy.get("JWT_SECRET")

  let assert Ok(jwt) = gwt.from_signed_string(session, secret)
  let assert Ok(user_id) = gwt.get_payload_claim(jwt, "user_id", decode.int)

  user_id
}

pub fn v1_register_invalid_req_body_test() {
  use ctx <- shutdown_context()

  let body = j.object([#("username", j.string(test_username))])
  let req = testing.post_json("/api/v1/auth/register", [], body)
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 422)
  ensure_error(resp, "Invalid request body")
}

pub fn v1_register_bad_conn_test() {
  let ctx = Context(conn: db.mock_connection())

  create_user_req(ctx, test_credentials, 500)
}

pub fn v1_register_success_test() {
  use ctx <- shutdown_context()

  include_user(ctx, test_credentials, fn() { Nil })
}

pub fn v1_register_already_exists_test() {
  use ctx <- shutdown_context()
  use <- include_user(ctx, test_credentials)

  create_user_req(ctx, test_credentials, 409)
}

pub fn v1_login_invalid_req_body_test() {
  use ctx <- shutdown_context()

  let body = j.object([#("username", j.string(test_username))])
  let req = testing.post_json("/api/v1/auth/login", [], body)
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 422)
  ensure_error(resp, "Invalid request body")
}

pub fn v1_login_success_test() {
  use ctx <- shutdown_context

  use session <- include_user_authorized(ctx, test_credentials)

  let user_id = payload_from_session(session)

  let assert Ok(pog.Returned(1, [user])) =
    sql.find_user_by_username(ctx.conn, test_username)
  assert user.id == user_id
}

pub fn v1_login_invalid_username_test() {
  use ctx <- shutdown_context()

  let body =
    j.object([
      #("username", j.string("_non_existent")),
      #("password", j.string(test_password)),
    ])
  let req = testing.post_json("/api/v1/auth/login", [], body)
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 401)
  ensure_error(resp, "Invalid username or password")
}

pub fn v1_login_invalid_password_test() {
  use ctx <- shutdown_context()

  let body =
    j.object([
      #("username", j.string(test_username)),
      #("password", j.string("incorrect")),
    ])
  let req = testing.post_json("/api/v1/auth/login", [], body)
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 401)
  ensure_error(resp, "Invalid username or password")
}

pub fn v1_session_test() {
  use ctx <- shutdown_context

  use session <- include_user_authorized(ctx, test_credentials)

  let user_id = payload_from_session(session)

  let req =
    testing.get("/api/v1/auth/session", [])
    |> testing.set_cookie("session", session, wisp.Signed)
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 200)
  use message <- ensure_body(resp, {
    use id <- decode.field("id", decode.int)
    use username <- decode.field("username", decode.string)
    decode.success(#(id, username))
  })
  assert message == #(user_id, test_username)
}

pub fn v1_logout_test() {
  use ctx <- shutdown_context()

  use session <- include_user_authorized(ctx, test_credentials)

  let req =
    testing.post("/api/v1/auth/logout", [], "")
    |> testing.set_cookie("session", session, wisp.Signed)
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 200)

  let assert Ok(max_age) =
    response.get_cookies(resp)
    |> dict.from_list()
    |> dict.get("Max-Age")

  assert max_age == "0"
}
