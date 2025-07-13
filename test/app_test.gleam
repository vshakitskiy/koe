import app/db
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

pub fn should_be_valid_resp(resp: response.Response(wisp.Body), status: Int) {
  let assert Ok(content_type) = response.get_header(resp, "Content-Type")
  assert content_type == "application/json; charset=utf-8"

  assert resp.status == status
}

pub fn with_body(
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

pub fn start_db_pool() -> actor.Started(pog.Connection) {
  let assert Ok(config) = db.parse_database_uri(db.process())

  let assert Ok(started) = pog.start(config)
  started
}

pub fn close_pool(conn: actor.Started(pog.Connection)) -> Nil {
  process.send_exit(conn.pid)
}

pub fn mock_conn() {
  pog.named_connection(db.process())
}
