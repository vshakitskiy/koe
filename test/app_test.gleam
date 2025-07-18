import app/db
import app/web.{type Context, Context}
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

pub fn ensure_body(
  resp: response.Response(wisp.Body),
  decoder: decode.Decoder(a),
  handle_success: fn(a) -> Nil,
) {
  let assert Ok(data) = resp |> testing.string_body() |> j.parse(decoder)
  handle_success(data)
}

pub fn start_db_pool() -> actor.Started(pog.Connection) {
  let assert Ok(config) = db.parse_database_uri(db.create_name())

  let assert Ok(started) = pog.start(config)
  started
}

pub fn close_pool(actor: actor.Started(pog.Connection)) -> Nil {
  process.send_exit(actor.pid)
}

pub fn shutdown_context(handle_test: fn(Context) -> Nil) {
  let pool = start_db_pool()
  handle_test(Context(conn: pool.data))
  close_pool(pool)
}

pub fn ensure_message(resp: response.Response(wisp.Body), target: String) -> Nil {
  use message <- ensure_body(resp, {
    use message <- decode.field("message", decode.string)
    decode.success(message)
  })
  assert message == target
}

pub fn ensure_error(resp: response.Response(wisp.Body), target: String) -> Nil {
  use error <- ensure_body(resp, {
    use error <- decode.field("error", decode.string)
    decode.success(error)
  })
  assert error == target
}
