///|
test "parse deterministic build date" {
  debug_inspect(
    @ssg.BuildDate::parse("2026-09-05T13:44:37"),
    content=(
      #|Some(
      #|  {
      #|    year: 2026,
      #|    month: 9,
      #|    day: 5,
      #|    hour: 13,
      #|    minute: 44,
      #|    second: 37,
      #|    utc_offset: "+0900",
      #|  },
      #|)
    ),
  )
  inspect(
    @ssg.BuildDate::parse("2026-09-05T06:42:08+0000").unwrap().utc_offset,
    content="+0000",
  )
  debug_inspect(@ssg.BuildDate::parse("2026-09-05"), content="None")
}
