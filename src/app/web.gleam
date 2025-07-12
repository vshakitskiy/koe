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

  use <- wisp.rescue_crashes()

  use req <- wisp.handle_head(req)

  handle_request(req)
}

pub fn unknown_endpoint() -> Response {
  j.object([#("error", j.string("Unknown endpoint"))])
  |> j.to_string_tree()
  |> wisp.json_body(wisp.not_found(), _)
}

pub fn internal(issue: a) -> Response {
  io.println_error("↓ INTERNAL ERROR ↓")
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
