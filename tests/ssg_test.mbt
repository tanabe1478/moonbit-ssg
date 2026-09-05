///|
test "the public API exposes the CLI banner" {
  inspect(@ssg.banner(), content="moonbit-ssg 0.1.0")
}
