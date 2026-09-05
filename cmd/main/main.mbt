///|
fn fail(message : String) -> Unit {
  @fs.write_string_to_file("/dev/stderr", "moonbit-ssg: \{message}\n") catch {
    _ => ()
  }
  @sys.exit(1)
}

///|
fn render_markdown_file(path : String) -> Unit {
  let source = @fs.read_file_to_string(path) catch {
    @fs.IOError(message) => {
      fail("unable to read \{path}: \{message}")
      return
    }
  }
  println(@ssg.render_markdown(@ssg.parse_source(source).markdown))
}

///|
fn main {
  let args = @env.args()
  if args.length() == 1 {
    println(@ssg.banner())
    return
  }
  if args.length() == 3 && args[1] == "render-markdown" {
    render_markdown_file(args[2])
    return
  }
  fail("usage: moonbit-ssg [render-markdown INPUT]")
}
