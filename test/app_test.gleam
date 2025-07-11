import app/db
import app/router
import app/web.{Context}
import gleam/dynamic/decode
import gleam/http/response
import gleam/json
import gleeunit
import gleeunit/should
import wisp/testing

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn v1_ensure_server_health_test() {
  let req = testing.get("/api/v1/health", [])
  let ctx = Context(db: db.connection())
  let resp = router.handle_request(req, ctx)

  resp.status |> should.equal(200)
  response.get_header(resp, "Content-Type")
  |> should.be_ok()
  |> should.equal("application/json; charset=utf-8")

  resp
  |> testing.string_body()
  |> json.parse({
    use status <- decode.field("status", decode.string)
    decode.success(status)
  })
  |> should.be_ok()
  |> should.equal("ok")
}
