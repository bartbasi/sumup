extends "res://tests/base_test.gd"
## BigNum (docs/ARCHITECTURE.md section 17): whole numbers of 0 or more with
## no fixed limit, for the score, points and charged amounts. Reference
## values were worked out with exact integer arithmetic outside Godot.

const INT64_MAX: int = 9223372036854775807
## 2^1000, 2^65535 and 2^65600 in decimal: digit count and the MD5 of the text.
const POWERS: Array[Array] = [
	[1000, 302, "2a2df6bb5d7697f790efa015185d2d6c"],
	[65535, 19729, "7c0ef83a78ef7bd977c58d6b493ed9c0"],
	[65600, 19748, "3fa4c9c8dba24e3616d11cda4c95b30b"],
]


func _n(text: String) -> BigNum:
	return BigNum.parse(text, 20000)


# Building numbers

func test_zero_and_from_int() -> void:
	assert_true(BigNum.zero().is_zero(), "zero is zero")
	assert_eq(BigNum.zero().to_decimal(), "0", "zero reads 0")
	assert_eq(BigNum.zero().bit_length(), 0, "zero has no bits")
	assert_true(BigNum.from_int(0).is_zero(), "from_int(0)")
	for value: int in [1, 9, 10, 999999999, 1000000000, 1000000001, 999999999999999999, 1000000000000000000, INT64_MAX]:
		assert_eq(BigNum.from_int(value).to_decimal(), str(value), "from_int(%d)" % value)
		assert_eq(BigNum.from_int(value).to_int(), value, "back to int %d" % value)


func test_pow2_small_and_at_limb_borders() -> void:
	var expected: Dictionary[int, String] = {
		0: "1", 1: "2", 31: "2147483648", 32: "4294967296", 62: "4611686018427387904",
		63: "9223372036854775808", 64: "18446744073709551616",
		100: "1267650600228229401496703205376", 127: "170141183460469231731687303715884105728",
	}
	for exponent: int in expected:
		assert_eq(BigNum.pow2(exponent).to_decimal(), expected[exponent], "2^%d" % exponent)
		assert_eq(BigNum.pow2(exponent).bit_length(), exponent + 1, "2^%d has %d bits" % [exponent, exponent + 1])


func test_pow2_large_values_match_the_reference() -> void:
	for row: Array in POWERS:
		var text: String = BigNum.pow2(row[0]).to_decimal()
		assert_eq(text.length(), row[1], "2^%d digit count" % row[0])
		assert_eq(text.md5_text(), row[2], "2^%d digits" % row[0])
	var ceiling: String = BigNum.pow2(65535).to_decimal()
	assert_true(ceiling.begins_with("10017649652034232324"), "2^65535 starts right")
	assert_true(ceiling.ends_with("22793947952859578368"), "2^65535 ends right")


func test_pow2_doubles_step_by_step() -> void:
	var running: BigNum = BigNum.from_int(1)
	for exponent: int in range(0, 1201):
		if not BigNum.pow2(exponent).equals(running):
			fail("2^%d differs from doubling %d times" % [exponent, exponent])
			return
		running = running.add(running)
	assert_true(BigNum.pow2(65534).add(BigNum.pow2(65534)).equals(BigNum.pow2(65535)), "2^65534 twice is 2^65535")
	assert_true(BigNum.pow2(65535).add(BigNum.pow2(65535)).equals(BigNum.pow2(65536)), "2^65535 twice is 2^65536")


func test_pow2_results_are_not_changed_by_later_use() -> void:
	var first: BigNum = BigNum.pow2(5000)
	var text: String = first.to_decimal()
	first.add(first)
	first.sub(BigNum.from_int(1))
	assert_eq(BigNum.pow2(5000).to_decimal(), text, "the cached 2^5000 is unchanged")


# parse

func test_parse_accepts_plain_digits() -> void:
	assert_eq(_n("0").to_decimal(), "0", "0")
	assert_eq(_n("7").to_int(), 7, "7")
	assert_eq(_n("1000000000").to_int(), 1000000000, "10^9, one limb border")
	assert_eq(_n("999999999").to_int(), 999999999, "just below it")
	assert_eq(_n("9223372036854775807").to_int(), INT64_MAX, "2^63 - 1")
	assert_eq(_n("9223372036854775808").to_decimal(), "9223372036854775808", "2^63")
	assert_true(_n("9223372036854775808").equals(BigNum.pow2(63)), "2^63 parsed equals pow2(63)")


func test_parse_refusals() -> void:
	var bad: PackedStringArray = [
		"", "-1", "+1", "01", "00", "007", "12a", "a12", "1.5", "1e9", " 1", "1 ", "1\n", "\n1",
		"1,000", "1_000", "0x10", "１２", "٣", "-0",
	]
	for text: String in bad:
		assert_null(BigNum.parse(text, 100), "refuses %s" % text.c_escape())


func test_parse_length_limit() -> void:
	assert_not_null(BigNum.parse("12345", 5), "5 digits with a limit of 5")
	assert_null(BigNum.parse("123456", 5), "6 digits with a limit of 5")
	assert_null(BigNum.parse("0", 0), "nothing passes a limit of 0")
	var longest: String = "9".repeat(19748)
	assert_not_null(BigNum.parse(longest, 19748), "19,748 digits at that limit")
	assert_null(BigNum.parse(longest + "9", 19748), "one more is refused")


func test_round_trips() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	for trial: int in 300:
		var length: int = rng.randi_range(1, 120)
		var text: String = str(rng.randi_range(1, 9))
		while text.length() < length:
			text += str(rng.randi_range(0, 9))
		var value: BigNum = _n(text)
		assert_eq(value.to_decimal(), text, "round trip %s" % text)
	for row: Array in POWERS:
		var text: String = BigNum.pow2(row[0]).to_decimal()
		assert_true(_n(text).equals(BigNum.pow2(row[0])), "2^%d reads back" % row[0])


# add, sub, compare

func test_add_carries_across_limbs() -> void:
	assert_eq(_n("999999999").add(BigNum.from_int(1)).to_decimal(), "1000000000", "one limb carry")
	assert_eq(_n("999999999999999999999999999").add(BigNum.from_int(1)).to_decimal(), "1000000000000000000000000000", "a carry through three limbs")
	assert_eq(BigNum.from_int(1).add(_n("999999999999999999")).to_decimal(), "1000000000000000000", "the shorter number first")
	assert_eq(BigNum.from_int(INT64_MAX).add(BigNum.from_int(1)).to_decimal(), "9223372036854775808", "past 2^63 - 1")
	assert_eq(BigNum.from_int(INT64_MAX).add(BigNum.from_int(INT64_MAX)).to_decimal(), "18446744073709551614", "two of the largest ints")
	assert_eq(BigNum.zero().add(BigNum.zero()).to_decimal(), "0", "0 + 0")
	assert_eq(BigNum.pow2(200).add(BigNum.zero()).to_decimal(), BigNum.pow2(200).to_decimal(), "x + 0")


## Bart's real numbers (2026-10-21): his score plus a 2^50 pair.
func test_bart_score_plus_a_2_50_pair() -> void:
	var score: BigNum = _n("9221253119629040934")
	assert_true(score.fits_int(), "his score still fit")
	var after: BigNum = score.add(BigNum.pow2(51))
	assert_eq(after.to_decimal(), "9223504919442726182", "plus 2^51")
	assert_true(after.equals(score.add(BigNum.pow2(50)).add(BigNum.pow2(50))), "the same as two 2^50 tiles")
	assert_false(after.fits_int(), "and no longer fits in 64 bits")
	assert_eq(after.compare(BigNum.from_int(INT64_MAX)), 1, "above 2^63 - 1")
	assert_eq(after.sub(BigNum.pow2(51)).to_decimal(), "9221253119629040934", "and back")


func test_sub_borrows_across_limbs() -> void:
	assert_eq(_n("1000000000").sub(BigNum.from_int(1)).to_decimal(), "999999999", "one limb borrow")
	assert_eq(_n("1000000000000000000000000000").sub(BigNum.from_int(1)).to_decimal(), "999999999999999999999999999", "a borrow through three limbs")
	assert_eq(BigNum.pow2(64).sub(BigNum.from_int(1)).to_decimal(), "18446744073709551615", "2^64 - 1")
	assert_true(BigNum.pow2(64).sub(BigNum.pow2(64)).is_zero(), "x - x is 0")
	assert_eq(BigNum.pow2(64).sub(BigNum.pow2(64)).to_decimal(), "0", "and reads 0")
	assert_eq(_n("5000000003000000007").sub(_n("5000000003000000000")).to_decimal(), "7", "top limbs cancel")
	assert_null(BigNum.from_int(5).sub(BigNum.from_int(6)), "null when the other is larger")
	assert_null(BigNum.zero().sub(BigNum.from_int(1)), "0 - 1 is null")
	assert_null(BigNum.pow2(100).sub(BigNum.pow2(101)), "null across lengths")
	var top: BigNum = BigNum.pow2(65600).sub(BigNum.from_int(1))
	assert_eq(top.bit_length(), 65600, "2^65600 - 1 has 65,600 bits")
	assert_true(top.add(BigNum.from_int(1)).equals(BigNum.pow2(65600)), "and plus 1 is 2^65600")


func test_operations_never_change_their_inputs() -> void:
	var a: BigNum = _n("123456789123456789123")
	var b: BigNum = _n("999999999999")
	a.add(b)
	a.sub(b)
	b.sub(a)
	a.compare(b)
	assert_eq(a.to_decimal(), "123456789123456789123", "a unchanged")
	assert_eq(b.to_decimal(), "999999999999", "b unchanged")


func test_compare_and_equals() -> void:
	var pairs: Array[Array] = [
		["0", "0", 0], ["0", "1", -1], ["1", "0", 1],
		["999999999", "1000000000", -1], ["1000000000", "999999999", 1],
		["1000000000000000001", "1000000000000000002", -1],
		["2000000000000000001", "1000000000000000002", 1],
		["9223372036854775807", "9223372036854775808", -1],
		["123456789123456789", "123456789123456789", 0],
	]
	for pair: Array in pairs:
		var a: BigNum = _n(pair[0])
		var b: BigNum = _n(pair[1])
		assert_eq(a.compare(b), pair[2], "%s against %s" % [pair[0], pair[1]])
		assert_eq(b.compare(a), -int(pair[2]), "%s against %s" % [pair[1], pair[0]])
		assert_eq(a.equals(b), pair[2] == 0, "equals %s %s" % [pair[0], pair[1]])
	assert_false(BigNum.zero().equals(null), "never equal to null")
	assert_true(_n("4294967296").equals(BigNum.pow2(32)), "the same number built two ways")


# bit_length, fits_int, to_int

func test_bit_length() -> void:
	var cases: Array[Array] = [
		["1", 1], ["2", 2], ["3", 2], ["4", 3], ["255", 8], ["256", 9],
		["4294967295", 32], ["4294967296", 33],
		["9223372036854775807", 63], ["9223372036854775808", 64], ["18446744073709551615", 64], ["18446744073709551616", 65],
		["1" + "0".repeat(30), 100], ["1" + "0".repeat(300), 997],
	]
	for case: Array in cases:
		assert_eq(_n(case[0]).bit_length(), case[1], "bits of %s" % case[0])
	for exponent: int in [64, 65, 100, 1000, 4000, 65535]:
		assert_eq(BigNum.pow2(exponent).bit_length(), exponent + 1, "2^%d" % exponent)
		assert_eq(BigNum.pow2(exponent).sub(BigNum.from_int(1)).bit_length(), exponent, "2^%d - 1" % exponent)
		assert_eq(BigNum.pow2(exponent).add(BigNum.from_int(1)).bit_length(), exponent + 1, "2^%d + 1" % exponent)


func test_fits_int_at_the_edge() -> void:
	assert_true(BigNum.zero().fits_int(), "0")
	assert_true(BigNum.from_int(INT64_MAX).fits_int(), "2^63 - 1")
	assert_true(_n("9223372036854775806").fits_int(), "2^63 - 2")
	assert_false(BigNum.pow2(63).fits_int(), "2^63")
	assert_false(_n("9223372036854775808").fits_int(), "2^63 parsed")
	assert_false(_n("9223372037000000000").fits_int(), "a larger middle limb")
	assert_false(_n("10000000000000000000").fits_int(), "a larger top limb")
	assert_false(_n("1" + "0".repeat(27)).fits_int(), "four limbs")
	assert_true(_n("8999999999999999999").fits_int(), "a smaller top limb")
	assert_eq(BigNum.from_int(INT64_MAX).to_int(), INT64_MAX, "to_int at the edge")


## The sizes the game can meet stay quick: 2^65600 (19,748 digits) prints and
## parses in well under 100 ms, and pow2 of the ceiling is cached once made.
func test_ceiling_sizes_are_quick() -> void:
	var big: BigNum = BigNum.pow2(65600).sub(BigNum.from_int(1))
	var start: int = Time.get_ticks_usec()
	var text: String = big.to_decimal()
	var printed: int = Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	var back: BigNum = BigNum.parse(text, 19748)
	var parsed: int = Time.get_ticks_usec() - start
	assert_true(back.equals(big), "the round trip is exact")
	assert_true(printed < 100000, "to_decimal took %d us" % printed)
	assert_true(parsed < 100000, "parse took %d us" % parsed)
	start = Time.get_ticks_usec()
	for repeat: int in 100:
		BigNum.pow2(65535)
	assert_true(Time.get_ticks_usec() - start < 100000, "pow2(65535) is cached")
