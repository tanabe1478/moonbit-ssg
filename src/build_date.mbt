///|
/// Local build time used by Publish's RSS and sitemap generators.
pub(all) struct BuildDate {
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
  utc_offset : String
} derive(Eq, Debug)

///|
fn parse_number(value : StringView) -> Int? {
  Some(@string.parse_int(value)) catch {
    _ => None
  }
}

///|
/// Parses `yyyy-MM-ddTHH:mm:ss` with an optional `+HHMM` UTC offset.
pub fn BuildDate::parse(value : String) -> BuildDate? {
  if (value.length() != 19 && value.length() != 24) ||
    value[4] != '-' ||
    value[7] != '-' ||
    value[10] != 'T' ||
    value[13] != ':' ||
    value[16] != ':' {
    return None
  }
  match
    (
      parse_number(value[:4]),
      parse_number(value[5:7]),
      parse_number(value[8:10]),
      parse_number(value[11:13]),
      parse_number(value[14:16]),
      parse_number(value[17:19]),
    ) {
    (Some(year), Some(month), Some(day), Some(hour), Some(minute), Some(second)) => {
      let utc_offset = if value.length() == 24 {
        value[19:24].to_owned()
      } else {
        "+0900"
      }
      if utc_offset.length() != 5 ||
        (utc_offset[0] != '+' && utc_offset[0] != '-') {
        return None
      }
      Some({ year, month, day, hour, minute, second, utc_offset, })
    }
    _ => None
  }
}

///|
fn current_build_date() -> BuildDate {
  let zone = @time.fixed_zone("JST", 9 * 60 * 60) catch {
    _ => abort("unable to construct JST timezone")
  }
  let unix_seconds = (@env.now() / 1000UL).reinterpret_as_int64()
  let date = @time.unix(unix_seconds, zone~) catch {
    _ => abort("unable to read current date")
  }
  {
    year: date.year(),
    month: date.month(),
    day: date.day(),
    hour: date.hour(),
    minute: date.minute(),
    second: date.second(),
    utc_offset: "+0900",
  }
}

///|
fn weekday_index(year : Int, month : Int, day : Int) -> Int {
  let mut adjusted_year = year
  let mut adjusted_month = month
  if adjusted_month < 3 {
    adjusted_year = adjusted_year - 1
    adjusted_month = adjusted_month + 12
  }
  (
    day +
    13 * (adjusted_month + 1) / 5 +
    adjusted_year +
    adjusted_year / 4 -
    adjusted_year / 100 +
    adjusted_year / 400
  ) %
  7
}

///|
fn weekday_name(year : Int, month : Int, day : Int) -> String {
  ["Sat", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri"][weekday_index(
    year, month, day,
  )]
}

///|
fn month_name(month : Int) -> String {
  [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ][month - 1]
}

///|
fn two_digits(value : Int) -> String {
  if value < 10 {
    "0\{value}"
  } else {
    value.to_string()
  }
}

///|
fn rfc822_date(date : BuildDate) -> String {
  "\{weekday_name(date.year, date.month, date.day)}, \{date.day} \{month_name(date.month)} \{date.year} \{two_digits(date.hour)}:\{two_digits(date.minute)}:\{two_digits(date.second)} \{date.utc_offset}"
}
