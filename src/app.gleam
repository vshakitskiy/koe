import app/db
import app/router
import app/v1/actors
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

pub fn start(_type, _args) -> Result(process.Pid, actor.StartError) {
  use <- bool.lazy_guard(env_or("MODE", "") != "MAIN", start_empty_supervisor)

  io.println("[app] Starting supervisor...")
  let supervisor = supervisor.new(supervisor.OneForOne)

  let postgresql_name = process.new_name("postgresql")
  let conn = db.from_name(postgresql_name)

  use config <- result.try(
    db.parse_database_uri(postgresql_name)
    |> result.replace_error(actor.InitFailed("Failed to parse database URI")),
  )
  let db_pool = pog.supervised(config)
  let supervisor = supervisor.add(supervisor, db_pool)

  let #(supervisor, rooms_manager) =
    actors.add_chat_actors(
      supervisor,
      name: process.new_name("manager"),
      rooms_amount: 1000,
      print_every: 100,
    )

  let jwt_secret = env_or("JWT_SECRET", wisp.random_string(64))
  let ctx = Context(conn:, jwt_secret:, rooms_manager:)

  let secret_key_base = env_or("SECRET_KEY_BASE", wisp.random_string(64))
  let port = env_or("PORT", "8080") |> int.parse |> result.unwrap(8080)

  let mist_server =
    mist.new(router.mist_handler(ctx, secret_key_base))
    |> mist.bind("0.0.0.0")
    |> mist.port(port)
    |> mist.supervised()
  let supervisor = supervisor.add(supervisor, mist_server)

  case supervisor.start(supervisor) {
    Error(error) -> Error(error)
    Ok(supervisor) -> Ok(supervisor.pid)
  }
}

pub fn main() -> Nil {
  process.sleep_forever()
}

fn start_empty_supervisor() {
  io.println("[app] Starting empty supervisor...")

  let supervisor =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.start()

  case supervisor {
    Error(error) -> Error(error)
    Ok(supervisor) -> Ok(supervisor.pid)
  }
}

fn env_or(name: String, default: String) -> String {
  envoy.get(name)
  |> result.unwrap(default)
}
