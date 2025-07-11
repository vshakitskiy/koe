import app/web.{type Context}
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use _req <- web.req_middleware(req)

  case wisp.path_segments(req) {
    ["api", ..segments] -> handle_api(req, ctx, segments)
    // TODO: websocket handler
    _ -> wisp.not_found()
  }
}

pub fn handle_api(
  req: Request,
  ctx: Context,
  segments: List(String),
) -> Response {
  case segments {
    ["v1", ..segments] -> handle_v1(req, ctx, segments)
    _ -> wisp.not_found()
  }
}

pub fn handle_v1(
  _req: Request,
  _ctx: Context,
  segments: List(String),
) -> Response {
  case segments {
    ["health"] -> handle_health_check()
    _ -> wisp.not_found()
  }
}

pub fn handle_health_check() -> Response {
  wisp.ok() |> wisp.string_body("OK")
}
