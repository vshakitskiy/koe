import app/db
import app/env
import app/router
import app/v1/actors
import app/web.{Context}
import gleam/erlang/process
import gleam/io
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/result
import mist
import pog

pub fn start(_type, _args) -> Result(process.Pid, actor.StartError) {
  io.println("[app] Starting application supervisor...")
  let supervisor =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.restart_tolerance(intensity: 1000, period: 1000)

  use env <- result.try(env.extract_env() |> result.map_error(actor.InitFailed))

  let postgresql_name = process.new_name("postgresql")
  let conn = db.from_name(postgresql_name)

  use config <- result.try(
    db.parse_database_uri(postgresql_name, env.database_url)
    |> result.map_error(actor.InitFailed),
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

  let ctx = Context(conn:, jwt_secret: env.jwt_secret, rooms_manager:)

  let mist_server =
    mist.new(router.mist_handler(ctx, env.secret_key_base))
    |> mist.bind("0.0.0.0")
    |> mist.port(env.port)
    |> mist.with_tls(env.certificate_path, env.keyfile_path)
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
