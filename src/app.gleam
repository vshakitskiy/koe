import app/router
import app/web
import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  let assert Ok(_) =
    wisp_mist.handler(
      router.handle_request(_, web.Context),
      wisp.random_string(64),
    )
    |> mist.new()
    |> mist.port(8080)
    |> mist.start()

  process.sleep_forever()
}
