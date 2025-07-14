import gleam/dynamic
import gleam/http
import gleam/io
import gleam/json as j
import pog
import wisp.{type Request, type Response}

pub type Context {
  Context(conn: pog.Connection)
}

pub fn req_middleware(
  req: Request,
  handle_request: fn(Request) -> Response,
) -> Response {
  let req = wisp.method_override(req)

  use <- wisp.log_request(req)

  use req <- wisp.handle_head(req)

  let resp = wisp.rescue_crashes(fn() { handle_request(req) })

  case resp.status, resp.body {
    500, wisp.Empty -> internal("server rescued during request, returning 500")
    _, _ -> resp
  }
}

pub fn unknown_endpoint() -> Response {
  j.object([#("error", j.string("Unknown endpoint"))])
  |> j.to_string_tree()
  |> wisp.json_body(wisp.not_found(), _)
}

pub fn internal(issue: a) -> Response {
  io.println_error("\n↓ INTERNAL ERROR ↓")
  echo issue

  j.object([#("error", j.string("Something went wrong, try again later"))])
  |> j.to_string_tree()
  |> wisp.json_body(wisp.internal_server_error(), _)
}

pub fn method_not_allowed(allowed: List(http.Method)) -> Response {
  j.object([#("error", j.string("Method not allowed"))])
  |> j.to_string_tree()
  |> wisp.json_body(wisp.method_not_allowed(allowed), _)
}

pub fn unsupported_media() -> Response {
  j.object([#("error", j.string("Content type must be application/json"))])
  |> j.to_string_tree()
  |> wisp.json_body(wisp.unsupported_media_type(["application/json"]), _)
}

pub fn invalid_json() -> Response {
  j.object([#("error", j.string("Invalid json body"))])
  |> j.to_string_tree()
  |> wisp.json_body(wisp.bad_request(), _)
}

pub fn request_too_large() -> Response {
  j.object([#("error", j.string("Request body is too large"))])
  |> j.to_string_tree()
  |> wisp.json_body(wisp.bad_request(), _)
}

pub fn invalid_body() -> Response {
  j.object([#("error", j.string("Invalid request body"))])
  |> j.to_string_tree()
  |> wisp.json_body(wisp.unprocessable_entity(), _)
}

pub fn require_json(
  req: Request,
  handle_request: fn(dynamic.Dynamic) -> Response,
) -> Response {
  let resp = wisp.require_json(req, handle_request)
  case resp.status {
    415 -> unsupported_media()
    413 -> request_too_large()
    400 -> invalid_json()
    _ -> resp
  }
}
