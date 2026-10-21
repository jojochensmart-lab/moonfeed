///|
/// RFC 4287 section 1.1 first example, compact whitespace only.
pub let rfc_feed : String =
  #|<?xml version="1.0" encoding="utf-8"?>
  #|<feed xmlns="http://www.w3.org/2005/Atom">
  #|<title>Example Feed</title><link href="http://example.org/"/>
  #|<updated>2003-12-13T18:30:02Z</updated><author><name>John Doe</name></author>
  #|<id>urn:uuid:60a76c80-d399-11d9-b93C-0003939e0af6</id>
  #|<entry><title>Atom-Powered Robots Run Amok</title><link href="http://example.org/2003/12/13/atom03"/>
  #|<id>urn:uuid:1225c695-cfb8-4ebb-aaaa-80da344efa6a</id>
  #|<updated>2003-12-13T18:30:02Z</updated><summary>Some text.</summary></entry></feed>

///|
pub let scoped_entry : String =
  #|<z:entry xmlns:z="http://www.w3.org/2005/Atom" xmlns:ext="urn:extension" xml:base="https://example.org/a/b/" xml:lang="en-US">
  #|<z:id>URN:entry:%7e</z:id><z:title xml:lang="zh-Hant">标题</z:title><z:updated>2003-12-13T18:30:02Z</z:updated>
  #|<z:source xml:base="../source/"><z:author><z:name>Source</z:name><z:uri>person</z:uri></z:author></z:source>
  #|<z:link xml:base="../" href="./story?edition=2#part" hreflang="EN-us"/>
  #|<z:summary xml:lang="">Neutral</z:summary><z:content type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml">A <b>B</b></div></z:content>
  #|<ext:title>Extension</ext:title></z:entry>

///|
pub let legacy_feed : String =
  #|<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="legacy_tag"><id>relative</id><title>Legacy</title><updated>2003-12-13T18:30:02Z</updated><entry><id>item</id><title>Item</title><updated>2003-12-13T18:30:02Z</updated></entry></feed>

///|
pub fn entry(attributes : String, body : String) -> String {
  "<entry xmlns='http://www.w3.org/2005/Atom' " +
  attributes +
  "><id>urn:conformance</id><title>Entry</title><updated>2003-12-13T18:30:02Z</updated><author><name>A</name></author>" +
  body +
  "</entry>"
}
