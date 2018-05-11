(i32.const 20)
(i32.const 18)
(i32.and)
#assertTopStack < i32 > 16 "and"

(i32.const 20)
(i32.const 18)
(i32.or)
#assertTopStack < i32 > 22 "or"

(i32.const 20)
(i32.const 18)
(i32.xor)
#assertTopStack < i32 > 6 "xor"

(i32.const 2)
(i32.const 1)
(i32.shl)
#assertTopStack < i32 > 4 "shl 1"

(i32.const 2)
(i32.const #pow1(i32) +Int 1)
(i32.shl)
#assertTopStack < i32 > 4 "shl 2"

(i32.const 2)
(i32.const #pow1(i32))
(i32.shr_u)
#assertTopStack < i32 > 2 ^Int 29 "shr_u 1"

(i32.const 2)
(i32.const 2)
(i32.shr_u)
#assertTopStack < i32 > 0 "shr_u 2"

(i32.const 1)
(i32.const #pow(i32) -Int 2)
(i32.shr_s)
#assertTopStack < i32 > #pow(i32) -Int 1 "shr_s 1"

(i32.const 2)
(i32.const 2)
(i32.shr_s)
#assertTopStack < i32 > 0 "shr_s 2"

(i32.const 3)
(i32.const #pow1(i32) +Int 2)
(i32.rotl)
#assertTopStack < i32 > 20 "rotl"

(i32.const 3)
(i32.const #pow1(i32) +Int 16)
(i32.rotr)
#assertTopStack < i32 > 2 ^Int 28 +Int 2 "rotr"

(i32.clz (i32.const 17))
#assertTopStack < i32 > 27 "clz 1"

(i32.clz (i32.const 252))
#assertTopStack < i32 > 24 "clz 2"

(i64.clz (i64.const 9007199254740991))
#assertTopStack < i64 > 11 "clz 3"

(i32.ctz (i32.const 176))
#assertTopStack < i32 > 4 "ctz 1"

(i32.ctz (i32.const 4202752))
#assertTopStack < i32 > 8 "ctz 2"

(i64.ctz (i64.const 1157433900327239680))
#assertTopStack < i64 > 43 "ctz 3"

(i32.popcnt (i32.const 17))
#assertTopStack < i32 > 2 "popcnt 1"

(i32.popcnt (i32.const 43))
#assertTopStack < i32 > 4 "popcnt 2"

(i32.popcnt (i32.const 17))
#assertTopStack < i32 > 2 "popcnt 3"
