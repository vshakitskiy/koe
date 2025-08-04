import app/v1/actors/manager
import app/v1/actors/room
import app/v1/actors/types
import app/web.{type Context}
import gleam/bytes_tree
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/io
import gleam/json as j
import gleam/option
import mist.{type Connection, type ResponseData}

pub type Session {
  Session(room: process.Subject(types.RoomMessage), conn: types.Connection)
}

pub fn handle_room_websocket(
  req: request.Request(Connection),
  ctx: Context,
  room_name: String,
  user: String,
) -> response.Response(ResponseData) {
  let room = manager.get_or_create_room(ctx.rooms_manager, room_name)

  case room {
    Ok(room) ->
      mist.websocket(
        request: req,
        on_init: fn(_conn) { on_init(room, user) },
        handler: handler,
        on_close: on_close,
      )
    Error(types.NoAvailableRooms) -> {
      j.object([#("error", j.string("No available rooms"))])
      |> j.to_string_tree()
      |> bytes_tree.from_string_tree()
      |> mist.Bytes()
      |> response.set_body(response.new(400), _)
      |> response.set_header("content-type", "application/json; charset=utf-8")
    }
  }
}

fn on_init(room: process.Subject(types.RoomMessage), user: String) {
  let subject = process.new_subject()

  let conn =
    types.Connection(pid: process.self(), reply_with: subject, user: user)
  room.join(room, conn)

  let selector =
    process.new_selector()
    |> process.select(subject)
    |> option.Some()

  io.println(user <> ": websocket opened, connected to room")

  #(Session(room:, conn:), selector)
}

fn handler(
  state: Session,
  message: mist.WebsocketMessage(types.Incoming),
  conn: mist.WebsocketConnection,
) {
  case message {
    mist.Custom(broadcast) -> {
      case broadcast {
        types.UserJoined(name, connected) -> {
          case
            j.object([
              #("event", j.string("user_joined")),
              #("username", j.string(name)),
              #("connected", j.array(connected, j.string)),
            ])
            |> j.to_string()
            |> mist.send_text_frame(conn, _)
          {
            Ok(Nil) -> mist.continue(state)
            Error(_) -> mist.stop()
          }
        }
        types.UserLeft(name, connected) -> {
          case
            j.object([
              #("event", j.string("user_left")),
              #("name", j.string(name)),
              #("connected", j.array(connected, j.string)),
            ])
            |> j.to_string()
            |> mist.send_text_frame(conn, _)
          {
            Ok(Nil) -> mist.continue(state)
            Error(_) -> mist.stop()
          }
        }
        types.MessageSent(name, message) -> {
          case
            j.object([
              #("event", j.string("new_message")),
              #("name", j.string(name)),
              #("message", j.string(message)),
            ])
            |> j.to_string()
            |> mist.send_text_frame(conn, _)
          {
            Ok(Nil) -> mist.continue(state)
            Error(_) -> mist.stop()
          }
        }
      }
    }
    mist.Text(text) -> {
      let parsed =
        j.parse(text, {
          use message <- decode.field("message", decode.string)

          decode.success(message)
        })

      case parsed {
        Ok(message) -> {
          room.broadcast_message(state.room, state.conn, message)
          mist.continue(state)
        }
        Error(_) -> mist.continue(state)
      }
    }
    rest -> {
      echo rest
      mist.continue(state)
    }
  }
}

fn on_close(state: Session) {
  room.leave(state.room, state.conn)
  io.println(state.conn.user <> ": websocket closed")
}
