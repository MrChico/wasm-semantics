(i32.wrap/i64 (i64.const #pow1(i64) -Int 15))
#assertTopStack < i32 > 4294967281 "wrapping down to i32"

(i64.extend_u/i32 (i32.const 58))
#assertTopStack < i64 > 58 "extending up to i64"

(i64.extend_s/i32 (i32.const -58))
#assertTopStack < i64 > -58 "extending negative number up to i64"
