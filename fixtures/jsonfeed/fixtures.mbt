///|
/// Minimal valid JSON Feed, shared by blackbox tests.
pub let minimal : String =
  #|{"version":"https://jsonfeed.org/version/1.1","title":"MoonFeed","items":[]}

///|
/// Complete supported field set, with author and language inheritance/overrides.
pub let full : String =
  #|{
  #|  "version":"https://jsonfeed.org/version/1.1",
  #|  "title":"MoonFeed 月刊",
  #|  "description":"MoonBit news",
  #|  "home_page_url":"https://example.org/",
  #|  "feed_url":"https://example.org/feed.json",
  #|  "language":"zh-CN",
  #|  "authors":[{"name":"Editor","url":"https://example.org/editor","avatar":"https://example.org/avatar.png"}],
  #|  "_extension":{"ignored":true},
  #|  "items":[
  #|    {
  #|      "id":"first","title":"First post",
  #|      "url":"https://example.org/first",
  #|      "external_url":"https://moonbitlang.com/",
  #|      "summary":"A summary","content_text":"Hello 🌙\nMoonBit",
  #|      "content_html":"<p>Hello &amp; MoonBit</p>",
  #|      "date_published":"2026-10-01T12:00:00+08:00",
  #|      "date_modified":"2026-10-01T13:00:00+08:00",
  #|      "tags":["MoonBit","新闻"]
  #|    },
  #|    {"id":"second","content_html":"<p>Second</p>","authors":[{"name":"Guest"}],"language":"en"},
  #|    {"id":"third","content_text":"","authors":[],"tags":[]}
  #|  ]
  #|}
