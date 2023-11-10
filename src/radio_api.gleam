import gleam/hackney
import mist.{Connection, ResponseData}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/bit_builder
import gleam/json
import gleam/io
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

pub fn get_song() -> Result(Song, hackney.Error) {
  // Prepare a HTTP request record
  let assert Ok(request) =
    request.to("https://www.christianrock.net/iphonecrdn.php")

  // Send the HTTP request to the server
  use response <- result.try(
    request
    |> request.set_cookie("SawOctober2023Splash", "Y")
    |> request.prepend_header("accept", "application/json")
    |> request.prepend_header("host", "www.christianrock.net")
    |> request.prepend_header(
      "user-agent",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
    )
    |> request.prepend_header(
      "referer",
      "https://www.christianrock.net/player.php?site=CRDN",
    )
    |> request.prepend_header("X-Requested-With", "XMLHttpRequest")
    |> request.set_cookie("SawOctober2023Splash", "Y")
    |> hackney.send,
  )

  song_from_json(response.body)
  |> result.map_error(fn(e) {
    e
    |> dynamic.from
    |> hackney.Other
  })
}

pub fn json_response(status: Int, body: json.Json) -> Response(ResponseData) {
  response.new(status)
  |> response.set_body(
    body
    |> json.to_string
    |> bit_builder.from_string
    |> mist.Bytes,
  )
  |> response.set_header("content-type", "application/json")
  |> response.set_header("access-control-allow-origin", "*")
}

pub fn error_response(status: Int, message: String) -> Response(ResponseData) {
  json_response(status, json.object([#("error", json.string(message))]))
}

pub fn http_service(req: Request(Connection)) -> Response(ResponseData) {
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
      |> io.debug
      |> result.unwrap(error_response(500, "Error getting the song"))
    _ -> error_response(404, "Not found")
  }
}

pub fn main() {
  let assert Ok(_) =
    http_service
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}
