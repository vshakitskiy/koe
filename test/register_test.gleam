import app/router
import app/v1/users/sql
import app/web.{type Context, Context}
import app_test.{close_pool, should_be_valid_resp, start_db_pool, with_body}
import gleam/dynamic/decode
import gleam/json as j
import pog
import wisp/testing

const test_username = "test_user"

const test_password = "Pa$$w0rD"

pub fn v1_register_user_invalid_req_body_test() {
  let pool = start_db_pool()
  let conn = pool.data
  let ctx = Context(conn:)

  let mock_register_user = j.object([#("username", j.string(test_username))])

  let req = testing.post_json("/api/v1/auth/register", [], mock_register_user)
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 422)

  use error <- with_body(resp, {
    use error <- decode.field("error", decode.string)
    decode.success(error)
  })
  assert error == "Invalid request body"

  close_pool(pool)
}

pub fn v1_register_user_success_test() {
  let pool = start_db_pool()
  let conn = pool.data
  let ctx = Context(conn:)

  clear_user(conn, test_username)

  create_user_req(ctx, test_username, test_password, 201)

  clear_user(conn, test_username)
  close_pool(pool)
}

pub fn v1_register_user_already_exists_test() {
  let pool = start_db_pool()
  let conn = pool.data
  let ctx = Context(conn:)

  clear_user(conn, test_username)

  create_user_req(ctx, test_username, test_password, 201)
  create_user_req(ctx, test_username, test_password, 409)

  clear_user(conn, test_username)
  close_pool(pool)
}

fn clear_user(conn: pog.Connection, username: String) {
  let assert Ok(_) = sql.delete_user_by_username(conn, username)
  Nil
}

fn create_user_req(
  ctx: Context,
  username: String,
  password: String,
  expected_status: Int,
) {
  let mock_register_user =
    j.object([
      #("username", j.string(username)),
      #("password", j.string(password)),
    ])

  let req = testing.post_json("/api/v1/auth/register", [], mock_register_user)
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, expected_status)

  case expected_status {
    201 -> {
      use message <- with_body(resp, {
        use message <- decode.field("message", decode.string)
        decode.success(message)
      })
      assert message == "User created successfully"
    }
    409 -> {
      use error <- with_body(resp, {
        use error <- decode.field("error", decode.string)
        decode.success(error)
      })
      assert error == "Username already taken"
    }
    _ -> panic as "Expected 201 or 409 for expected_status argument"
  }
}
