import app/v1/router as v1
import app/web.{type Context}
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.req_middleware(req)

  case wisp.path_segments(req) {
    ["api", ..segments] -> handle_api(req, ctx, segments)
    // TODO: websocket handler
    _ -> web.unknown_endpoint()
  }
}

pub fn handle_api(
  req: Request,
  ctx: Context,
  segments: List(String),
) -> Response {
  case segments {
    ["v1", ..segments] -> v1.handle_v1_rest(req, ctx, segments)
    _ -> web.unknown_endpoint()
  }
}
