import app/v1/actors/manager
import app/v1/actors/room
import app/v1/actors/types
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/otp/static_supervisor as supervisor

pub type RoomsManager =
  process.Subject(types.ManagerMessage)

pub fn add_chat_actors(
  builder: supervisor.Builder,
  name name: process.Name(types.ManagerMessage),
  rooms_amount n: Int,
  print_every every: Int,
) {
  let manager_subject = process.named_subject(name)

  let #(builder, rooms) =
    start_rooms(builder, n, #(n, every), manager_subject, [])

  let manager = manager.supervised(name, rooms)
  #(supervisor.add(builder, manager), manager_subject)
}

pub fn start_rooms(
  builder: supervisor.Builder,
  n: Int,
  config: #(Int, Int),
  manager_subject: process.Subject(types.ManagerMessage),
  acc: List(process.Subject(types.RoomMessage)),
) {
  case n {
    0 -> {
      io.println("Starting rooms... " <> int.to_string(config.0 - 1))
      #(builder, acc)
    }
    n -> {
      let _ = case n % config.1 {
        0 -> io.println("Starting rooms... " <> int.to_string(config.0 - n))
        _ -> Nil
      }
      let room_name = process.new_name("room" <> int.to_string(n))
      let room_subject = process.named_subject(room_name)

      let room = room.supervised(room_name, manager_subject)
      start_rooms(
        supervisor.add(builder, room),
        n - 1,
        config,
        manager_subject,
        [room_subject, ..acc],
      )
    }
  }
}
