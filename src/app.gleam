import app/db
import app/router
import app/web.{Context}
import envoy
import gleam/bool
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/result
import mist
import pog
import wisp
import wisp/wisp_mist

pub fn start(_type, _args) -> Result(process.Pid, actor.StartError) {
  let mode =
    envoy.get("MODE")
    |> result.unwrap("START")
  use <- bool.lazy_guard(mode != "START", fn() {
    io.println("Starting empty supervisor process (mode: " <> mode <> ")")

    let supervisor =
      supervisor.new(supervisor.OneForOne)
      |> supervisor.start()

    case supervisor {
      Error(error) -> Error(error)
      Ok(supervisor) -> Ok(supervisor.pid)
    }
  })

  io.println("Starting main supervisor process (mode: " <> mode <> ")")

  let postgresql = db.create_name()

  let config = case db.parse_database_uri(postgresql) {
    Ok(config) -> config
    Error(error) -> {
      io.println_error("↓ Failed to parse database URI ↓")
      echo error
      halt()
    }
  }

  let db_pool = pog.supervised(config)

  let conn = db.from_name(postgresql)
  let ctx = Context(conn:)

  let secret_key_base =
    envoy.get("SECRET_KEY_BASE")
    |> result.unwrap(wisp.random_string(64))

  let port =
    envoy.get("PORT")
    |> result.try(int.parse)
    |> result.unwrap(8080)

  let mist_server =
    router.handle_request(_, ctx)
    |> wisp_mist.handler(secret_key_base)
    |> mist.new()
    |> mist.bind("0.0.0.0")
    |> mist.port(port)
    |> mist.supervised()

  let supervisor =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(db_pool)
    |> supervisor.add(mist_server)
    |> supervisor.start()

  case supervisor {
    Error(error) -> Error(error)
    Ok(supervisor) -> Ok(supervisor.pid)
  }
}

pub fn main() -> Nil {
  process.sleep_forever()
}

@external(erlang, "erlang", "halt")
fn halt() -> a
