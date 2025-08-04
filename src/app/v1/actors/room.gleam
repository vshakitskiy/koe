import app/v1/actors/types.{type ManagerMessage, type RoomMessage}
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/otp/supervision

pub type Subscribers =
  dict.Dict(process.Pid, types.Connection)

pub type Status {
  Idle
  Closing
  Active(name: String, subscribers: Subscribers)
}

pub type Room {
  Room(manager: Subject(ManagerMessage), status: Status)
}

pub fn start(name: process.Name(RoomMessage), manager: Subject(ManagerMessage)) {
  actor.new(Room(manager:, status: Idle))
  |> actor.named(name)
  |> actor.on_message(handle_message)
  |> actor.start()
}

pub fn supervised(
  name: process.Name(RoomMessage),
  manager: Subject(ManagerMessage),
) {
  supervision.supervisor(fn() { start(name, manager) })
}

pub fn join(room: Subject(RoomMessage), conn: types.Connection) {
  io.println("User joined: " <> conn.user)
  actor.send(room, types.Join(conn))
}

pub fn leave(room: Subject(RoomMessage), conn: types.Connection) {
  io.println("User left: " <> conn.user)
  actor.send(room, types.Leave(conn))
}

pub fn broadcast_message(
  room: Subject(RoomMessage),
  conn: types.Connection,
  message: String,
) {
  io.println("Broadcasting message: `" <> message <> "` from " <> conn.user)
  actor.send(room, types.Message(conn, message))
}

fn handle_message(state: Room, message: RoomMessage) {
  case message {
    types.Assign(name) ->
      actor.continue(Room(..state, status: Active(name, dict.new())))
    types.Reset -> actor.continue(Room(..state, status: Idle))

    types.Join(conn) -> {
      use name, subscribers <- ensure_active(state)
      let subscribers = dict.insert(subscribers, conn.pid, conn)
      let connected =
        dict.values(subscribers)
        |> list.map(fn(conn) { conn.user })

      dict.each(subscribers, fn(_, conn) {
        actor.send(
          conn.reply_with,
          types.UserJoined(username: conn.user, connected:),
        )
      })

      actor.continue(Room(..state, status: Active(name:, subscribers:)))
    }
    types.Message(conn, message) -> {
      use _, subscribers <- ensure_active(state)
      let username = conn.user

      dict.each(subscribers, fn(_, conn) {
        actor.send(conn.reply_with, types.MessageSent(username:, message:))
      })

      actor.continue(state)
    }
    types.Leave(conn) -> {
      use name, subscribers <- ensure_active(state)
      let subscribers = dict.drop(subscribers, [conn.pid])
      let connected =
        dict.values(subscribers)
        |> list.map(fn(conn) { conn.user })

      case connected {
        [] -> {
          actor.send(state.manager, types.ReleaseRoom(name))
          actor.continue(Room(..state, status: Closing))
        }
        _ -> {
          dict.each(subscribers, fn(_, conn) {
            actor.send(
              conn.reply_with,
              types.UserLeft(username: conn.user, connected:),
            )
          })

          actor.continue(Room(..state, status: Active(name:, subscribers:)))
        }
      }
    }
  }
}

fn ensure_active(
  state: Room,
  handle_active: fn(String, Subscribers) -> actor.Next(Room, a),
) -> actor.Next(Room, a) {
  case state.status {
    Active(name, subscribers) -> handle_active(name, subscribers)
    Closing -> actor.continue(state)
    Idle -> actor.continue(state)
  }
}
