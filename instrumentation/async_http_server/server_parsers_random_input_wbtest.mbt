struct ServerFuzzRng {
  state : Ref[Int64]
}

fn ServerFuzzRng::new(seed : Int64) -> ServerFuzzRng {
  { state: Ref(seed), }
}

fn ServerFuzzRng::next(self : ServerFuzzRng) -> Int64 {
  let mut x = self.state.val
  x = x ^ (x >> 12)
  x = x ^ (x << 25)
  x = x ^ (x >> 27)
  self.state.val = x
  x
}

fn ServerFuzzRng::below(self : ServerFuzzRng, bound : Int32) -> Int32 {
  let value = self.next() & 0x7FFFFFFFFFFFFFFFL
  (value % bound.to_int64()).to_int()
}

let server_fuzz_fragments : Array[String] = [
  "a", "Z", "0", "9", ":", "/", "//", "?", "#", "@", "[", "]", "%", "%25",
  "%zz", ".", "-", "_", "+", "~", "!", "$", "&", "'", "(", ")", "*", ",", ";",
  "=", " ", "\t", "\r", "\n", "é", "🤣", "\u{0}", "\\", "\"", "<", ">", "|",
  "http", "https", "HTTP", "for", "by", "host", "proto", "\"\"", "\\\"",
]

fn server_fuzz_text(rng : ServerFuzzRng, max : Int32) -> String {
  let sb = StringBuilder()
  let count = rng.below(max + 1)
  let mut i = 0
  while i < count {
    sb.write_view(server_fuzz_fragments[rng.below(server_fuzz_fragments.length())][:])
    i = i + 1
  }
  sb.to_string()
}

test "server_parsers_do_not_panic_on_random_input" {
  let rng = ServerFuzzRng::new(0x2468_ACE0_1357_9BDFL)
  let mut i = 0
  while i < 20000 {
    let text = server_fuzz_text(rng, 24)
    let _ = split_path_query(text)
    let _ = absolute_target_scheme_end(text)
    let _ = http_absolute_target_scheme_end(text)
    let _ = absolute_target_authority(text)
    let _ = is_absolute_target(text)
    let _ = request_target_scheme(text)
    let _ = split_host_authority(text, 80)
    let _ = parse_content_length(text[:])
    let _ = parse_forwarded_node(text)
    let _ = unquote_forwarded_value(text[:])
    let _ = has_close_token(text)
    let _ = is_usable_content_length(text)
    let _ = sanitize_utf16_surrogates(text)
    let _ = sanitize_wire_header_value(text)
    let _ = is_bracketed_ip_literal(text)
    let _ = is_ipv4_literal(text[:])
    let _ = is_ipvfuture_literal(text[:])
    if text.length() > 0 {
      let _ = is_valid_ipv6_zone(text[:])
    }
    i = i + 1
  }
}
