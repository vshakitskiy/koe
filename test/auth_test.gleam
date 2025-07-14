import app/db
import app/router
import app/v1/users/sql
import app/web.{type Context, Context}
import app_test.{ensure_body, should_be_valid_resp, shutdown_context}
import gleam/dynamic/decode
import gleam/json as j
import pog
import wisp/testing

const test_username = "test_user"

const test_password = "Pa$$w0rD"

const test_credentials = #(test_username, test_password)

fn create_user_req(ctx: Context, creds: #(String, String), expected_status: Int) {
  let mock_register_user =
    j.object([
      #("username", j.string(creds.0)),
      #("password", j.string(creds.1)),
    ])

  let req = testing.post_json("/api/v1/auth/register", [], mock_register_user)
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, expected_status)

  case expected_status {
    201 -> {
      use message <- ensure_body(resp, {
        use message <- decode.field("message", decode.string)
        decode.success(message)
      })
      assert message == "User created successfully"
    }
    409 -> {
      use error <- ensure_body(resp, {
        use error <- decode.field("error", decode.string)
        decode.success(error)
      })
      assert error == "Username already taken"
    }
    500 -> {
      use error <- ensure_body(resp, {
        use error <- decode.field("error", decode.string)
        decode.success(error)
      })
      assert error == "Something went wrong, try again later"
    }
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
  create_user_req(ctx, creds, 201)
  handle_test()
  clear_user(ctx.conn, creds.0)
}

pub fn v1_register_user_invalid_req_body_test() {
  use ctx <- shutdown_context()

  let mock_register_user = j.object([#("username", j.string(test_username))])
  let req = testing.post_json("/api/v1/auth/register", [], mock_register_user)
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 422)

  use error <- ensure_body(resp, {
    use error <- decode.field("error", decode.string)
    decode.success(error)
  })
  assert error == "Invalid request body"
}

pub fn v1_register_user_bad_conn_test() {
  let ctx = Context(conn: db.mock_connection())

  create_user_req(ctx, test_credentials, 500)
}

pub fn v1_register_user_success_test() {
  use ctx <- shutdown_context()

  clear_user(ctx.conn, test_username)

  include_user(ctx, test_credentials, fn() { Nil })
}

pub fn v1_register_user_already_exists_test() {
  use ctx <- shutdown_context()
  clear_user(ctx.conn, test_username)

  use <- include_user(ctx, test_credentials)

  create_user_req(ctx, test_credentials, 409)
}
