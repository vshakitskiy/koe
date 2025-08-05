import app/v1/api as api_v1
import app/v1/ws as ws_v1
import app/web.{type Context}
import gleam/http/request
import gleam/http/response
import mist.{type Connection, type ResponseData}
import wisp
import wisp/wisp_mist

pub fn mist_handler(ctx: Context, secret_key_base: String) {
  fn(req: request.Request(Connection)) -> response.Response(ResponseData) {
    case request.path_segments(req) {
      // TODO: join websockets with authentication
      ["api", "v1", "rooms", room_name, "ws"] ->
        ws_v1.handle_room_websocket(req, ctx, room_name)
      segments -> {
        let mist_to_wisp = wisp_handler(_, ctx, segments)
        let handler = wisp_mist.handler(mist_to_wisp, secret_key_base)
        handler(req)
      }
    }
  }
}

pub fn wisp_handler(
  req: wisp.Request,
  ctx: Context,
  segments: List(String),
) -> wisp.Response {
  use req <- web.root_middleware(req)

  case segments {
    ["api", "v1", ..segments] -> api_v1.handle_request(req, ctx, segments)
    _ -> web.unknown_endpoint()
  }
}

pub fn handle_request(req: wisp.Request, ctx: Context) -> wisp.Response {
  wisp_handler(req, ctx, request.path_segments(req))
}
