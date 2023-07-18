import gleam/hackney
import mist
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/bit_builder.{BitBuilder}
import gleam/json
import gleam/result
import gleam/dynamic
import gleam/erlang/process

pub type Song {
  Song(artist: String, title: String)
}

fn song_from_json(json: String) -> Result(Song, json.DecodeError) {
  let song_decoder =
    dynamic.decode2(
      Song,
      dynamic.field("Artist", of: dynamic.string),
      dynamic.field("Title", of: dynamic.string),
    )

  json.decode(from: json, using: song_decoder)
}

pub fn get_song() {
  // Prepare a HTTP request record
  let assert Ok(request) =
    request.to("https://www.christianrock.net/iphonecrdn.php")

  // Send the HTTP request to the server
  use response <- result.try(
    request
    |> request.prepend_header("accept", "application/json")
    |> hackney.send,
  )

  use song <- result.try(
    song_from_json(response.body)
    |> result.map_error(fn(e) {
      e
      |> dynamic.from
      |> hackney.Other
    }),
  )

  Ok(song)
}

pub fn json_response(status: Int, body: json.Json) -> Response(BitBuilder) {
  response.new(status)
  |> response.set_body(
    body
    |> json.to_string
    |> bit_builder.from_string,
  )
  |> response.set_header("content-type", "application/json")
  |> response.set_header("access-control-allow-origin", "*")
}

pub fn error_response(status: Int, message: String) -> Response(BitBuilder) {
  json_response(status, json.object([#("error", json.string(message))]))
}

pub fn http_service(req: Request(BitString)) -> Response(BitBuilder) {
  case request.path_segments(req) {
    ["christianrock"] ->
      get_song()
      |> result.map(fn(song) {
        json_response(
          200,
          json.object([
            #("artist", json.string(song.artist)),
            #("title", json.string(song.title)),
          ]),
        )
      })
      |> result.unwrap(error_response(500, "Error getting the song"))
    _ -> error_response(404, "Not found")
  }
}

pub fn main() {
  let assert Ok(_) =
    mist.run_service(8000, http_service, max_body_limit: 4_000_000)
  process.sleep_forever()
}
