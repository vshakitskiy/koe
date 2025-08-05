import app/db
import app/env
import app/v1/actors
import app/v1/actors/types
import app/web.{type Context, Context}
import envoy
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http/response
import gleam/io
import gleam/json as j
import gleam/otp/static_supervisor as supervisor
import gleam/result
import gleeunit
import pog
import wisp
import wisp/testing

pub fn main() -> Nil {
  case start_test_supervisor() {
    Error(error) -> io.println_error("Failed to run tests: " <> error)
    Ok(_supervisor) -> gleeunit.main()
  }
}

fn start_test_supervisor() {
  io.println("[test] Starting test supervisor...")

  let supervisor = supervisor.new(supervisor.OneForOne)

  use database_url <- result.try(env.database_url())

  use config <- result.try(db.parse_database_uri(
    postgresql_name(),
    database_url,
  ))
  let db_pool = pog.supervised(config)
  let supervisor = supervisor.add(supervisor, db_pool)

  let #(supervisor, _manager_subject) =
    actors.add_chat_actors(
      supervisor,
      name: manager_name(),
      rooms_amount: 2,
      print_every: 2,
    )

  supervisor.start(supervisor)
  |> result.replace_error("Failed to start supervisor")
}

pub fn ensure_body(
  resp: response.Response(wisp.Body),
  decoder: decode.Decoder(a),
  handle_success: fn(a) -> Nil,
) {
  let assert Ok(content_type) = response.get_header(resp, "Content-Type")
  assert content_type == "application/json; charset=utf-8"

  let assert Ok(data) = resp |> testing.string_body() |> j.parse(decoder)
  handle_success(data)
}

pub fn context() -> Context {
  let assert Ok(jwt_secret) = envoy.get("JWT_SECRET")

  Context(
    conn: db.from_name(postgresql_name()),
    jwt_secret:,
    rooms_manager: process.named_subject(manager_name()),
  )
}

pub fn mock_context() -> Context {
  Context(
    conn: db.mock_connection(),
    jwt_secret: "",
    rooms_manager: process.new_subject(),
  )
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

@external(erlang, "app_ffi", "atom_from_string")
fn name_from_string(string string: String) -> process.Name(message)

fn postgresql_name() -> process.Name(pog.Message) {
  name_from_string("postgresql$test")
}

fn manager_name() -> process.Name(types.ManagerMessage) {
  name_from_string("manager$test")
}
