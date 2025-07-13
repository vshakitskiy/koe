import app/v1/users/sql
import app/web.{type Context}
import argus
import gleam/dynamic/decode
import gleam/http
import gleam/json as j
import gleam/result.{try}
import pog
import wisp.{type Request, type Response}

pub fn handle_auth(
  req: Request,
  ctx: Context,
  segments: List(String),
) -> Response {
  case req.method, segments {
    http.Post, ["register"] -> register(req, ctx)
    http.Post, ["login"] -> login(req, ctx)

    _, ["register"] | _, ["login"] -> web.method_not_allowed([http.Post])
    _, _ -> web.unknown_endpoint()
  }
}

// type User {
//   User(id: Int, username: String, password_: String)
// }

fn register(req: Request, ctx: Context) -> Response {
  use json <- web.require_json(req)

  let resp = {
    use #(username, password) <- try(
      decode.run(json, {
        use username <- decode.field("username", decode.string)
        use password <- decode.field("password", decode.string)
        decode.success(#(username, password))
      })
      |> result.replace_error(web.invalid_body()),
    )

    use hashes <- try(
      argus.hasher()
      |> argus.algorithm(argus.Argon2id)
      |> argus.time_cost(3)
      |> argus.memory_cost(12_228)
      |> argus.parallelism(1)
      |> argus.hash_length(32)
      |> argus.hash(password, argus.gen_salt())
      |> result.map_error(web.internal),
    )

    case sql.create_user(ctx.conn, username, hashes.encoded_hash) {
      Ok(pog.Returned(count: 1, rows: _)) ->
        Ok(
          j.object([#("message", j.string("User created successfully"))])
          |> j.to_string_tree()
          |> wisp.json_body(wisp.created(), _),
        )
      Error(pog.ConstraintViolated(_, _, _)) ->
        Error(
          j.object([#("error", j.string("Username already taken"))])
          |> j.to_string_tree()
          |> wisp.json_body(wisp.response(409), _),
        )

      Error(issue) -> Error(web.internal(issue))
      Ok(never) -> Error(web.internal(never))
    }
  }

  result.unwrap_both(resp)
}

fn login(req: Request, ctx: Context) -> Response {
  todo
}
