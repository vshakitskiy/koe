import app/v1/actors
import app/web/jwt
import envoy
import gleam/bit_array
import gleam/bytes_tree
import gleam/crypto
import gleam/dict
import gleam/dynamic
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/io
import gleam/json as j
import gleam/list
import gleam/result
import gleam/string
import mist
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
    Error(_) -> error_resp(401, "Unauthorized")
    Ok(session) -> {
      case jwt.verify_token(session, ctx.jwt_secret) {
        Error(_) -> error_resp(401, "Unauthorized")
        Ok(claims) -> handle_request(claims)
      }
    }
  }
}

pub fn mist_auth_middleware(
  req: request.Request(mist.Connection),
  ctx: Context,
  handle_request: fn(jwt.Claims) -> response.Response(mist.ResponseData),
) -> response.Response(mist.ResponseData) {
  let session = {
    use session <- result.try(
      request.get_cookies(req)
      |> dict.from_list()
      |> dict.get("session"),
    )
    let assert Ok(secret_key_base) = envoy.get("SECRET_KEY_BASE")
    use session <- result.try(
      crypto.verify_signed_message(session, <<secret_key_base:utf8>>)
      |> result.map(bit_array.to_string)
      |> result.flatten(),
    )

    jwt.verify_token(session, ctx.jwt_secret) |> result.replace_error(Nil)
  }

  case session {
    Ok(claims) -> handle_request(claims)
    Error(Nil) -> mist_error_resp(401, "Unauthorized")
  }
}

pub fn return_result(
  handle_request: fn() -> Result(Response, Response),
) -> Response {
  handle_request()
  |> result.unwrap_both()
}

pub fn resp(status: Int, body: j.Json) -> Response {
  j.to_string_tree(body)
  |> wisp.json_body(wisp.response(status), _)
}

pub fn mist_resp(
  status: Int,
  body: j.Json,
) -> response.Response(mist.ResponseData) {
  j.to_string_tree(body)
  |> bytes_tree.from_string_tree()
  |> mist.Bytes()
  |> response.set_body(response.new(status), _)
  |> response.set_header("content-type", "application/json; charset=utf-8")
}

pub fn error_resp(status: Int, error: String) -> Response {
  j.object([#("error", j.string(error))])
  |> resp(status, _)
}

pub fn mist_error_resp(
  status: Int,
  error: String,
) -> response.Response(mist.ResponseData) {
  j.object([#("error", j.string(error))])
  |> mist_resp(status, _)
}

pub fn message_resp(status: Int, message: String) -> Response {
  j.object([#("message", j.string(message))])
  |> resp(status, _)
}

pub fn invalid_json() -> Response {
  error_resp(400, "Invalid json body")
}

pub fn unknown_endpoint() -> Response {
  error_resp(404, "Unknown endpoint")
}

pub fn method_not_allowed(allowed: List(http.Method)) -> Response {
  list.map(allowed, http.method_to_string)
  |> list.sort(string.compare)
  |> string.join(", ")
  |> response.set_header(error_resp(405, "Method not allowed"), "allow", _)
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
  error_resp(413, "Request body is too large")
}

pub fn unsupported_media() -> Response {
  error_resp(415, "Content type must be application/json")
  |> response.set_header("allow", "application/json")
}

pub fn invalid_body() -> Response {
  error_resp(422, "Invalid request body")
}

pub fn internal(issue: a) -> Response {
  io.println_error("\n↓ INTERNAL ERROR ↓")
  echo issue

  error_resp(500, "Something went wrong, try again later")
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
