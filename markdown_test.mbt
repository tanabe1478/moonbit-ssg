///|
test "render common Markdown with Ink HTML shape" {
  inspect(
    @moonbit-ssg.render_markdown(
      (
        #|# Hello
        #|
        #|Paragraph with *emphasis*, **strong**, [link](/url), and `code`.
        #|
        #|![Alt](image.png)
        #|
        #|- One
        #|- Two
        #|
        #|> Quote
      ),
    ),
    content=(
      #|<h1>Hello</h1><p>Paragraph with <em>emphasis</em>, <strong>strong</strong>, <a href="/url">link</a>, and <code>code</code>.</p><img src="image.png" alt="Alt"/><ul><li>One</li><li>Two</li></ul><blockquote><p>Quote</p></blockquote>
    ),
  )
}

///|
test "preserve Ink behavior at CRLF boundaries" {
  let source = "# Title\n\n## Section\r\n\r\nBody\r\n\r\n- Item"
  inspect(
    @moonbit-ssg.render_markdown(source),
    content="<h1>Title</h1><h2>Section Body - Item</h2>",
  )
}

///|
test "finish a standalone CRLF image before the next paragraph" {
  let source = "# Title\n\n![Alt](image.png)\r\n\r\nBody"
  inspect(
    @moonbit-ssg.render_markdown(source),
    content="<h1>Title</h1><img src=\"image.png\" alt=\"Alt\"/><p>Body</p>",
  )
}

///|
test "preserve Ink nested and separated list shapes" {
  inspect(
    @moonbit-ssg.render_markdown(
      (
        #|- Parent
        #|  - Nested
        #|- Following
        #|  - Child one
        #|  - Child two
      ),
    ),
    content=(
      #|<ul><li>Parent<ul><li>Nested</li><li>Following</li><li>Child one</li><li>Child two</li></ul></li></ul>
    ),
  )
  inspect(
    @moonbit-ssg.render_markdown(
      (
        #|1. First
        #|   - Child
        #|
        #|2. Second
        #|   - Child
      ),
    ),
    content=(
      #|<ol><li>First<ul><li>Child</li></ul></li></ol><ol start="2"><li>Second<ul><li>Child</li></ul></li></ol>
    ),
  )
}

///|
test "apply the blog YouTube modifier" {
  inspect(
    @moonbit-ssg.render_markdown("> youtube https://youtu.be/video-id?t=10"),
    content=(
      #|<div class="youtube"><iframe width="560" height="315" src="https://www.youtube.com/embed//video-id" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe></div>
    ),
  )
}

///|
test "apply HighlightJS-compatible shell and Swift markup" {
  inspect(
    @moonbit-ssg.render_markdown(
      (
        #|```sh
        #|echo user's value'
        #|```
      ),
    ),
    content=(
      #|<pre data-language="sh" class="hljs"><code>echo user<span class="hljs-string">'s value'</span>
      #|</code></pre>
    ),
  )
  inspect(
    @moonbit-ssg.render_markdown(
      (
        #|```swift
        #|try Blog(value: "text", enabled: true) // comment
        #|```
      ),
    ),
    content=(
      #|<pre data-language="swift" class="hljs"><code><span class="hljs-keyword">try</span> <span class="hljs-type">Blog</span>(value: <span class="hljs-string">"text"</span>, enabled: <span class="hljs-literal">true</span>) <span class="hljs-comment">// comment</span>
      #|</code></pre>
    ),
  )
}
