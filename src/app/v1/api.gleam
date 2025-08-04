import app/v1/users
import app/web.{type Context}
import gleam/http
import gleam/json as j
import wisp.{type Request, type Response}

pub fn handle_request(
  req: Request,
  ctx: Context,
  segments: List(String),
) -> Response {
  case segments {
    ["health"] -> handle_health_check(req)

    ["auth", ..segments] -> users.handle_auth(req, ctx, segments)

    _ -> web.unknown_endpoint()
  }
}

pub fn handle_health_check(req: Request) -> Response {
  case req.method {
    http.Get ->
      j.object([#("status", j.string("ok"))])
      |> j.to_string_tree()
      |> wisp.json_body(wisp.ok(), _)
    _ -> web.method_not_allowed([http.Get])
  }
}
