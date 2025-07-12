import app/db
import app/router
import app/web.{Context}
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http/response
import gleam/json as j
import gleam/otp/actor
import gleeunit
import pog
import wisp
import wisp/testing

pub fn main() -> Nil {
  gleeunit.main()
}

fn should_be_valid_resp(resp: response.Response(wisp.Body), status: Int) {
  // let assert Ok(content_type) = response.get_header(resp, "Content-Type")
  // assert content_type == "application/json; charset=utf-8"

  assert resp.status == status
}

fn with_body(
  resp: response.Response(wisp.Body),
  decoder: decode.Decoder(a),
  handle_success: fn(a) -> Nil,
) {
  let assert Ok(data) =
    resp
    |> testing.string_body()
    |> j.parse(decoder)

  handle_success(data)
}

fn start_db_pool() -> actor.Started(pog.Connection) {
  let assert Ok(config) = db.parse_database_uri(db.process())

  let assert Ok(started) = pog.start(config)
  started
}

fn close_pool(conn: actor.Started(pog.Connection)) -> Nil {
  process.send_exit(conn.pid)
}

fn mock_conn() {
  pog.named_connection(db.process())
}

pub fn v1_ensure_server_health_test() {
  let req = testing.get("/api/v1/health", [])
  let ctx = Context(conn: mock_conn())
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 200)

  use status <- with_body(resp, {
    use status <- decode.field("status", decode.string)
    decode.success(status)
  })
  assert status == "ok"
}

pub fn unknown_endpoint_test() {
  let req = testing.get("/foobar", [])
  let ctx = Context(conn: mock_conn())
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 404)

  use error <- with_body(resp, {
    use error <- decode.field("error", decode.string)
    decode.success(error)
  })
  assert error == "Unknown endpoint"
}

pub fn v1_invalid_method_test() {
  let req = testing.get("/api/v1/auth/register", [])
  let ctx = Context(conn: mock_conn())
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 405)

  use error <- with_body(resp, {
    use error <- decode.field("error", decode.string)
    decode.success(error)
  })
  assert error == "Method not allowed"
}

const test_username = "test_user_9"

const test_password = "Pa$$w0rD"

pub fn v1_register_user_success_test() {
  let pool = start_db_pool()
  let conn = pool.data

  let mock_register_user =
    j.object([
      #("username", j.string(test_username)),
      #("password", j.string(test_password)),
    ])

  let req = testing.post_json("/api/v1/auth/register", [], mock_register_user)
  let ctx = Context(conn:)
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 201)

  use message <- with_body(resp, {
    use message <- decode.field("message", decode.string)
    decode.success(message)
  })
  assert message == "User created successfully"

  close_pool(pool)
}

pub fn v1_register_user_already_exists_test() {
  let pool = start_db_pool()
  let conn = pool.data

  let mock_register_user =
    j.object([
      #("username", j.string(test_username)),
      #("password", j.string(test_password)),
    ])

  let req = testing.post_json("/api/v1/auth/register", [], mock_register_user)
  let ctx = Context(conn:)
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 409)

  use error <- with_body(resp, {
    use error <- decode.field("error", decode.string)
    decode.success(error)
  })
  assert error == "Username already taken"

  close_pool(pool)
}
