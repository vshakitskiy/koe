import app/db
import app/router
import app/web.{Context}
import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor
import mist
import pog
import wisp
import wisp/wisp_mist

pub fn start(_type, _args) {
  let db_name = db.process()

  let db = pog.named_connection(db_name)
  let assert Ok(db_pool) = db.connection_pool(db_name)

  let ctx = Context(db:)
  let secret_key_base = wisp.random_string(64)

  let mist_server =
    router.handle_request(_, ctx)
    |> wisp_mist.handler(secret_key_base)
    |> mist.new()
    |> mist.bind("0.0.0.0")
    |> mist.port(8080)
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
