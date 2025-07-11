import gleam/http/request
import gleam/httpc
import gleeunit

const api_url = "http://localhost:8080"

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn v1_ensure_server_health_test() {
  let assert Ok(base_req) = request.to(api_url <> "/api/v1/health")
  let assert Ok(resp) = httpc.send(base_req) as "server is not alive!"

  assert resp.status == 200
  assert resp.body == "OK"
}
