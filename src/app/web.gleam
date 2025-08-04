import app/v1/actors
import app/web/jwt
import gleam/dynamic
import gleam/http
import gleam/http/response
import gleam/io
import gleam/json as j
import gleam/list
import gleam/result
import gleam/string
import pog
import wisp.{type Request, type Response}

pub type Context {
  Context(
    conn: pog.Connection,
    jwt_secret: String,
    rooms_manager: actors.RoomsManager,
  )
}

pub fn root_middleware(
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

pub fn auth_middleware(
  req: Request,
  ctx: Context,
  handle_request: fn(jwt.Claims) -> Response,
) -> Response {
  case wisp.get_cookie(req, "session", wisp.Signed) {
    Error(_) -> error_response(401, "Unauthorized")
    Ok(session) -> {
      case jwt.verify_token(session, ctx.jwt_secret) {
        Error(_) -> error_response(401, "Unauthorized")
        Ok(claims) -> handle_request(claims)
      }
    }
  }
}

pub fn return_result(
  handle_request: fn() -> Result(Response, Response),
) -> Response {
  handle_request()
  |> result.unwrap_both()
}

pub fn error_response(status: Int, error: String) -> Response {
  j.object([#("error", j.string(error))])
  |> j.to_string_tree()
  |> wisp.json_body(wisp.response(status), _)
}

pub fn message_response(status: Int, message: String) -> Response {
  j.object([#("message", j.string(message))])
  |> j.to_string_tree()
  |> wisp.json_body(wisp.response(status), _)
}

pub fn invalid_json() -> Response {
  error_response(400, "Invalid json body")
}

pub fn unknown_endpoint() -> Response {
  j.object([#("error", j.string("Unknown endpoint"))])
  |> j.to_string_tree()
  |> wisp.json_body(wisp.not_found(), _)
}

pub fn method_not_allowed(allowed: List(http.Method)) -> Response {
  list.map(allowed, http.method_to_string)
  |> list.sort(string.compare)
  |> string.join(", ")
  |> response.set_header(error_response(405, "Method not allowed"), "allow", _)
}

pub fn require_method(
  req: Request,
  method: http.Method,
  handle_request: fn() -> Response,
) -> Response {
  case req.method == method {
    True -> handle_request()
    False -> method_not_allowed([method])
  }
}

pub fn request_too_large() -> Response {
  error_response(413, "Request body is too large")
}

pub fn unsupported_media() -> Response {
  error_response(415, "Content type must be application/json")
  |> response.set_header("content-type", "application/json; charset=utf-8")
}

pub fn invalid_body() -> Response {
  error_response(422, "Invalid request body")
}

pub fn internal(issue: a) -> Response {
  io.println_error("\n↓ INTERNAL ERROR ↓")
  echo issue

  error_response(500, "Something went wrong, try again later")
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
