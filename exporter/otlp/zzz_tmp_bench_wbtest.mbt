// Temporary investigation benchmarks (deleted after analysis).

test "tmp bench array for-in 10" (b : @bench.T) {
  let arr : Array[Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  b.bench(fn() {
    let mut n = 0
    for x in arr {
      n = n + x
    }
    b.keep(n)
  })
}

test "tmp bench array each 10" (b : @bench.T) {
  let arr : Array[Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  b.bench(fn() {
    let mut n = 0
    arr.each(fn(x) { n = n + x })
    b.keep(n)
  })
}

test "tmp bench array indexed 10" (b : @bench.T) {
  let arr : Array[Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  b.bench(fn() {
    let mut n = 0
    let mut i = 0
    while i < arr.length() {
      n = n + arr.unsafe_get(i)
      i = i + 1
    }
    b.keep(n)
  })
}

test "tmp bench array for-in empty" (b : @bench.T) {
  let arr : Array[Int] = []
  b.bench(fn() {
    let mut n = 0
    for x in arr {
      n = n + x
    }
    b.keep(n)
  })
}

test "tmp bench array each empty" (b : @bench.T) {
  let arr : Array[Int] = []
  b.bench(fn() {
    let mut n = 0
    arr.each(fn(x) { n = n + x })
    b.keep(n)
  })
}
