///|
const VERSION = "0.1.0"

///|
fn main {
  let args = @env.args()
  let args = if args.length() >= 2 { args[2:] } else { [] }
  match args {
    ["--help"] | ["-h"] => print(help_text())
    ["--version"] | ["-V"] => print("moonfeed " + VERSION + "\n")
    [command, path] if command == "detect" ||
      command == "inspect" ||
      command == "normalize" => {
      let input = read_input_or_exit(path)
      if input == "" {
        fail("moonfeed: input is empty\n", 2)
      }
      if command == "detect" {
        match detect_name(input) {
          Ok(name) => print(name + "\n")
          Err(_) => fail("moonfeed: Unknown feed format\n", 2)
        }
      } else {
        match parse_feed(input) {
          Ok(feed) =>
            if command == "inspect" {
              match detect_name(input) {
                Ok(format) => print(inspect_feed(feed, format))
                Err(_) => print(inspect_feed(feed, "Unknown"))
              }
            } else {
              print(feed_json(feed).stringify(indent=2) + "\n")
            }
          Err(error) =>
            fail(
              "moonfeed: failed to parse \"" + path + "\":\n  " + error + "\n",
              2,
            )
        }
      }
    }
    _ => fail(help_text(), 2)
  }
}

///|
fn detect_name(input : String) -> Result[String, String] {
  try {
    match @detect.detect_format(input) {
      @detect.JsonFeed => Ok("JSON Feed 1.1")
      @detect.Rss => Ok("RSS 2.0")
      @detect.Atom => Ok("Atom 1.0")
    }
  } catch {
    error => Err(@debug.to_string(error))
  }
}

///|
fn parse_feed(input : String) -> Result[@model.Feed, String] {
  Ok(@moonfeed.parse(input)) catch {
    error => Err(@debug.to_string(error))
  }
}

///|
fn help_text() -> String {
  "MoonFeed - parse and normalize RSS, Atom and JSON Feed\n\nUsage:\n  moonfeed detect <file|->\n  moonfeed inspect <file|->\n  moonfeed normalize <file|->\n  moonfeed --help\n  moonfeed --version\n\nCommands:\n  detect      Detect the feed format\n  inspect     Show a human-readable feed summary\n  normalize   Convert a feed to normalized JSON\n"
}

///|
fn inspect_feed(feed : @model.Feed, format : String) -> String {
  let out = StringBuilder()
  out.write_string("Format: " + format + "\n")
  out.write_string("Title: " + feed.title + "\n")
  out.write_string("Home: " + optional(feed.home_page_url) + "\n")
  out.write_string("Feed URL: " + optional(feed.feed_url) + "\n")
  out.write_string("Language: " + optional(feed.language) + "\n")
  out.write_string("Items: " + feed.items.length().to_string() + "\n")
  out.write_string("Updated: " + optional(feed.updated) + "\n")
  out.write_string(
    "Updated UTC: " +
    optional_i64_text(feed.updated_at.map(value => value.unix_seconds)) +
    "\n\nItems:\n",
  )
  let limit = if feed.items.length() < 5 { feed.items.length() } else { 5 }
  for index = 0; index < limit; index = index + 1 {
    let item = feed.items[index]
    out.write_string(
      "\n" + (index + 1).to_string() + ". " + optional(item.title) + "\n",
    )
    out.write_string("   ID: " + item.id + "\n")
    out.write_string("   URL: " + optional(item.url) + "\n")
    out.write_string("   Published: " + optional(item.published) + "\n")
    out.write_string("   Categories: " + join(item.categories, ", ") + "\n")
  }
  out.to_string()
}

///|
fn feed_json(feed : @model.Feed) -> Json {
  object([
    ("title", Json::string(feed.title)),
    ("description", optional_json(feed.description)),
    ("home_page_url", optional_json(feed.home_page_url)),
    ("feed_url", optional_json(feed.feed_url)),
    ("language", optional_json(feed.language)),
    ("updated", optional_json(feed.updated)),
    (
      "updated_unix",
      optional_i64(feed.updated_at.map(value => value.unix_seconds)),
    ),
    ("authors", Json::array(feed.authors.map(author => author_json(author)))),
    (
      "categories",
      Json::array(feed.categories.map(value => Json::string(value))),
    ),
    ("items", Json::array(feed.items.map(item => item_json(item)))),
  ])
}

///|
fn item_json(item : @model.FeedItem) -> Json {
  object([
    ("id", Json::string(item.id)),
    ("title", optional_json(item.title)),
    ("url", optional_json(item.url)),
    ("external_url", optional_json(item.external_url)),
    ("summary", optional_json(item.summary)),
    ("content_text", optional_json(item.content_text)),
    ("content_html", optional_json(item.content_html)),
    ("published", optional_json(item.published)),
    (
      "published_unix",
      optional_i64(item.published_at.map(value => value.unix_seconds)),
    ),
    ("updated", optional_json(item.updated)),
    (
      "updated_unix",
      optional_i64(item.updated_at.map(value => value.unix_seconds)),
    ),
    ("authors", Json::array(item.authors.map(author => author_json(author)))),
    (
      "categories",
      Json::array(item.categories.map(value => Json::string(value))),
    ),
    (
      "attachments",
      Json::array(item.attachments.map(value => attachment_json(value))),
    ),
  ])
}

///|
fn author_json(author : @model.Author) -> Json {
  object([
    ("name", optional_json(author.name)),
    ("url", optional_json(author.url)),
    ("avatar", optional_json(author.avatar)),
  ])
}

///|
fn attachment_json(value : @model.Attachment) -> Json {
  object([
    ("url", Json::string(value.url)),
    ("mime_type", Json::string(value.mime_type)),
    ("title", optional_json(value.title)),
    (
      "size_in_bytes",
      match value.size_in_bytes {
        Some(number) =>
          Json::number(number.to_double(), repr=number.to_string())
        None => Json::null()
      },
    ),
    (
      "duration_in_seconds",
      match value.duration_in_seconds {
        Some(number) => Json::number(number)
        None => Json::null()
      },
    ),
  ])
}

///|
fn object(fields : Array[(String, Json)]) -> Json {
  let result : Map[String, Json] = Map([])
  for (key, value) in fields {
    result.set(key, value)
  }
  Json::object(result)
}

///|
fn optional_json(value : String?) -> Json {
  match value {
    Some(text) => Json::string(text)
    None => Json::null()
  }
}

///|
fn optional_i64(value : Int64?) -> Json {
  match value {
    Some(number) => Json::number(number.to_double(), repr=number.to_string())
    None => Json::null()
  }
}

///|
fn optional_i64_text(value : Int64?) -> String {
  match value {
    Some(number) => number.to_string()
    None => "-"
  }
}

///|
fn optional(value : String?) -> String {
  match value {
    Some(text) => text
    None => "-"
  }
}

///|
fn join(values : Array[String], separator : String) -> String {
  let out = StringBuilder()
  for index, value in values {
    if index > 0 {
      out.write_string(separator)
    }
    out.write_string(value)
  }
  out.to_string()
}

///|
fn print(text : String) -> Unit {
  host_write(text, false)
}

///|
fn fail(text : String, code : Int) -> Unit {
  host_write(text, true)
  host_exit(code)
}

///|
fn read_input_or_exit(path : String) -> String {
  let value = host_read(path)
  if value.has_prefix("\u{0}ERR:") {
    fail("moonfeed: " + value.to_string_view()[5:].to_owned() + "\n", 2)
    ""
  } else {
    value
  }
}

///|
#cfg(target="js")
extern "js" fn host_read(path : String) -> String =
  #| function(path) {
  #|   try {
  #|     const fs = require("fs");
  #|     return path === "-" ? fs.readFileSync(0, "utf8") : fs.readFileSync(path, "utf8");
  #|   } catch (error) {
  #|     return "\u0000ERR:" + (error && error.code === "ENOENT" ? "file not found: " : "cannot read input: ") + String(error && error.message || error);
  #|   }
  #| }

///|
#cfg(not(target="js"))
fn host_read(_path : String) -> String {
  "\u{0}ERR:CLI file I/O requires JavaScript target"
}

///|
#cfg(target="js")
extern "js" fn host_write(text : String, is_error : Bool) -> Unit =
  #| function(text, is_error) { (is_error ? process.stderr : process.stdout).write(text); }

///|
#cfg(not(target="js"))
fn host_write(text : String, _is_error : Bool) -> Unit {
  println(text)
}

///|
#cfg(target="js")
extern "js" fn host_exit(code : Int) -> Unit =
  #| function(code) { process.exit(code); }

///|
#cfg(not(target="js"))
fn host_exit(_code : Int) -> Unit {
  ()
}
