///|
pub let minimal : String =
  #|<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom"><id>urn:feed:minimal</id><title>Minimal</title><updated>2026-10-01T10:00:00Z</updated></feed>

///|
pub let full : String =
  #|<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en"><id>urn:feed:full</id><title type="html"><![CDATA[News &amp; Updates]]></title><subtitle>Short summary</subtitle><updated>2026-10-01T10:00:00Z</updated><link rel="self" href="https://example.org/feed.atom" type="application/atom+xml"/><link href="https://example.org/"/><author><name>Editor</name><uri>https://example.org/editor</uri><email>editor@example.org</email></author><contributor><name>Guest</name></contributor><category term="moonbit" scheme="https://example.org/topics" label="MoonBit"/><rights>Copyright</rights><generator uri="https://example.org">MoonFeed</generator><icon>https://example.org/icon.png</icon><logo>https://example.org/logo.png</logo><entry><id>urn:entry:one</id><title>Release 1.0</title><updated>2026-10-01T09:00:00Z</updated><published>2026-09-30T09:00:00Z</published><link href="https://example.org/releases/1"/><category term="release"/><summary type="text">First release</summary><content type="html">&lt;p&gt;Ready &amp;amp; stable&lt;/p&gt;</content><rights>Entry rights</rights><source><id>urn:source</id><title>Source feed</title><updated>2026-09-01T00:00:00Z</updated></source></entry></feed>

///|
pub let multiple_entries : String =
  #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:multi</id><title>Multiple</title><updated>2024-01-02T03:04:05Z</updated><entry><id>one</id><title>One</title><updated>2024-01-02T03:04:05Z</updated></entry><entry><id>two</id><title>Two</title><updated>2024-01-02T03:04:05Z</updated></entry></feed>

///|
pub let enclosure : String =
  #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:enc</id><title>Media</title><updated>2024-01-02T03:04:05Z</updated><entry><id>audio</id><title>Audio</title><updated>2024-01-02T03:04:05Z</updated><link rel="enclosure" href="https://example.org/a.mp3" type="audio/mpeg" length="120" title="Audio"/><link rel="self" href="https://example.org/entries/audio"/><link rel="alternate" href="https://example.org/audio"/></entry></feed>

///|
pub let namespaced : String =
  #|<atom:feed xmlns:atom="http://www.w3.org/2005/Atom" xmlns:ext="urn:extension"><atom:id>urn:prefix</atom:id><atom:title>Prefixed</atom:title><atom:updated>2024-01-02T03:04:05Z</atom:updated><atom:entry><atom:id>e</atom:id><atom:title><![CDATA[A & B]]></atom:title><atom:updated>2024-01-02T03:04:05Z</atom:updated><ext:title>Ignore me</ext:title></atom:entry></atom:feed>

///|
pub let github_release : String =
  #|<feed xmlns="http://www.w3.org/2005/Atom"><id>tag:github.com,2008:Repository/42/releases</id><title>Example releases</title><updated>2026-10-01T10:00:00Z</updated><link rel="self" href="https://github.com/example/project/releases.atom"/><link href="https://github.com/example/project/releases"/><entry><id>tag:github.com,2008:Repository/42/v1.2.0</id><title>Example v1.2.0</title><updated>2026-10-01T10:00:00Z</updated><published>2026-10-01T09:00:00Z</published><author><name>octocat</name></author><link href="https://github.com/example/project/releases/tag/v1.2.0"/><category term="Release"/></entry></feed>

///|
pub let tech_blog : String =
  #|<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="zh-CN"><id>https://blog.example.org/atom.xml</id><title>技术博客</title><subtitle>编程与工具</subtitle><updated>2026-09-28T08:00:00+08:00</updated><link rel="self" href="https://blog.example.org/atom.xml"/><link href="https://blog.example.org/"/><author><name>博主</name><uri>https://blog.example.org/about</uri></author><category term="MoonBit"/><entry><id>https://blog.example.org/posts/moonfeed</id><title>MoonFeed 开发记录</title><updated>2026-09-28T08:00:00+08:00</updated><summary>一篇技术文章</summary><content type="html">&lt;p&gt;构建 &amp;amp; 解析&lt;/p&gt;</content></entry></feed>
