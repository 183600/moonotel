///|
fn diff_ts(s : String) -> Unit {
  let a = parse_tracestate(s)
  let b = match Tracestate::parse(s) {
    Some(state) => Some(state.to_header())
    None => None
  }
  if a != b {
    abort("mismatch for tracestate: " + s)
  }
}

///|
test "tracestate differential crafted" {
  let cases : Array[String] = [
    "", " ", "\t", ",", ",,", ",,,", "a=1", "a=1,", ",a=1", ",a=1,", " a=1 ", "a = 1",
    "a =1", "a= 1", "a=1 , b=2", "a=1,b=2", "a=1,a=1", "a=1, a=1", "a=1,a=2", "A=1",
    "a=1=2", "a=", "=1", "a", "a=1,b=2,c=3", "a=1, b = 2,,", "a=1,b", "a=1,,b=2",
    "a=1\t", "\ta=1", "a\t=1", "a=1\t", "a= 1", "a=  1", "a=1 ,b=2", "a=1, b=2 ",
    "a=1 , ,b=2", "a=1;x=2", "a=1,b=2,", "a=1,b=2, ", "a b=1", "0=1", "a_b=1", "a-b=1",
    "a*b=1", "a/b=1", "a@b=1", "a=1@2", "a=1,b=2,c=3,d=4,e=5,f=6,g=7,h=8,i=9,j=10,k=11,l=12,m=13,n=14,o=15,p=16,q=17,r=18,s=19,t=20,u=21,v=22,w=23,x=24,y=25,z=26,aa=27,ab=28,ac=29,ad=30,ae=31,af=32,ag=33",
  ]
  for s in cases {
    diff_ts(s)
  }
}

///|
test "tracestate differential long" {
  let sb = StringBuilder()
  for i = 0; i < 6; i = i + 1 {
    if i > 0 {
      sb.write_char(',')
    }
    sb.write_string("k" + i.to_string() + "=")
    for j = 0; j < 120; j = j + 1 {
      sb.write_char('v')
    }
  }
  diff_ts(sb.to_string())
  let sb2 = StringBuilder()
  for i = 0; i < 4; i = i + 1 {
    if i > 0 {
      sb2.write_char(',')
    }
    sb2.write_string("k" + i.to_string() + "=")
    for j = 0; j < 170; j = j + 1 {
      sb2.write_char('v')
    }
  }
  diff_ts(sb2.to_string())
}
