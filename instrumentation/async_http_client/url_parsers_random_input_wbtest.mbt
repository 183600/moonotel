///|
struct UrlFuzzRng {
  state : Ref[Int64]
}

///|
fn UrlFuzzRng::new(seed : Int64) -> UrlFuzzRng {
  { state: Ref(seed), }
}

///|
fn UrlFuzzRng::next(self : UrlFuzzRng) -> Int64 {
  let mut x = self.state.val
  x = x ^ (x >> 12)
  x = x ^ (x << 25)
  x = x ^ (x >> 27)
  self.state.val = x
  x
}

///|
fn UrlFuzzRng::below(self : UrlFuzzRng, bound : Int32) -> Int32 {
  let value = self.next() & 0x7FFFFFFFFFFFFFFFL
  (value % bound.to_int64()).to_int()
}

///|
let url_fuzz_fragments : Array[String] = [
  "a", "Z", "0", "9", ":", "/", "//", "?", "#", "@", "[", "]", "%", "%25", "%zz",
  ".", "-", "_", "+", "~", "!", "$", "&", "'", "(", ")", "*", ",", ";", "=", " ",
  "\t", "\r", "\n", "é", "🤣", "\u{0}", "\\", "\"", "<", ">", "|",
]

///|
fn url_fuzz_text(rng : UrlFuzzRng, max : Int32) -> String {
  let sb = StringBuilder()
  let count = rng.below(max + 1)
  let mut i = 0
  while i < count {
    sb.write_view(url_fuzz_fragments[rng.below(url_fuzz_fragments.length())][:])
    i = i + 1
  }
  sb.to_string()
}

///|
test "url_parsers_do_not_panic_on_random_input" {
  let rng = UrlFuzzRng::new(0x1357_9BDF_2468_ACE0L)
  let mut i = 0
  while i < 20000 {
    let text = url_fuzz_text(rng, 24)
    let _ = split_scheme(text)
    let _ = split_url(text)
    let _ = split_url_parts(text)
    let _ = split_url_path_query(text)
    let _ = url_fragment(text)
    let _ = redact_url(text)
    let _ = normalize_url_for_transport(text)
    let _ = split_url_for_transport(text)
    let _ = connect_authority_target(text)
    i = i + 1
  }
}
