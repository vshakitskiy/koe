import app/db
import app/router
import app/web.{Context}
import app_test.{ensure_body, should_be_valid_resp}
import gleam/dynamic/decode
import wisp/testing

pub fn unknown_endpoint_test() {
  let req = testing.get("/foobar", [])
  let ctx = Context(conn: db.mock_connection())
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 404)

  use error <- ensure_body(resp, {
    use error <- decode.field("error", decode.string)
    decode.success(error)
  })
  assert error == "Unknown endpoint"
}

pub fn v1_ensure_server_health_test() {
  let req = testing.get("/api/v1/health", [])
  let ctx = Context(conn: db.mock_connection())
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 200)

  use status <- ensure_body(resp, {
    use status <- decode.field("status", decode.string)
    decode.success(status)
  })
  assert status == "ok"
}

pub fn v1_invalid_method_test() {
  let req = testing.post("/api/v1/health", [], "")
  let ctx = Context(conn: db.mock_connection())
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 405)

  use error <- ensure_body(resp, {
    use error <- decode.field("error", decode.string)
    decode.success(error)
  })
  assert error == "Method not allowed"
}

pub fn v1_not_a_json_request_test() {
  let req = testing.post("/api/v1/auth/register", [], "")
  let ctx = Context(conn: db.mock_connection())
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 415)

  use error <- ensure_body(resp, {
    use error <- decode.field("error", decode.string)
    decode.success(error)
  })
  assert error == "Content type must be application/json"
}

pub fn v1_bad_req_json_test() {
  let req =
    testing.post(
      "/api/v1/auth/register",
      [#("content-type", "application/json")],
      "{",
    )
  let ctx = Context(conn: db.mock_connection())
  let resp = router.handle_request(req, ctx)

  should_be_valid_resp(resp, 400)

  use error <- ensure_body(resp, {
    use error <- decode.field("error", decode.string)
    decode.success(error)
  })
  assert error == "Invalid json body"
}
