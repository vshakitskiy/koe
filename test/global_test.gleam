import app/router
import app_test.{ensure_body, ensure_error, mock_context}
import gleam/dynamic/decode
import wisp/testing

pub fn unknown_endpoint_test() {
  let req = testing.get("/foobar", [])

  let resp = router.handle_request(req, mock_context())
  assert resp.status == 404

  ensure_error(resp, "Unknown endpoint")
}

fn health_resp_decoder() -> decode.Decoder(String) {
  use status <- decode.field("status", decode.string)
  decode.success(status)
}

pub fn v1_ensure_server_health_test() {
  let req = testing.get("/api/v1/health", [])

  let resp = router.handle_request(req, mock_context())
  assert resp.status == 200

  use status <- ensure_body(resp, health_resp_decoder())
  assert status == "ok"
}

pub fn v1_invalid_method_test() {
  let req = testing.post("/api/v1/health", [], "")

  let resp = router.handle_request(req, mock_context())
  assert resp.status == 405
  ensure_error(resp, "Method not allowed")
}

pub fn v1_not_a_json_request_test() {
  let req = testing.post("/api/v1/auth/register", [], "")

  let resp = router.handle_request(req, mock_context())
  assert resp.status == 415
  ensure_error(resp, "Content type must be application/json")
}

pub fn v1_bad_req_json_test() {
  let req =
    testing.post(
      "/api/v1/auth/register",
      [#("content-type", "application/json")],
      "{",
    )

  let resp = router.handle_request(req, mock_context())
  assert resp.status == 400
  ensure_error(resp, "Invalid json body")
}
