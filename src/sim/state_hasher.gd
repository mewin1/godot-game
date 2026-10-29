class_name StateHasher
extends RefCounted
## Считает хэш состояния симуляции из целых чисел. Одинаковое состояние — одинаковый хэш
## на любом компьютере. Нужен для теста детерминизма и (позже) проверки рассинхрона по сети.

const MODULUS: int = 1_000_000_007
const BASE: int = 131

var value: int = 7


func add(number: int) -> void:
	value = (value * BASE + posmod(number, MODULUS)) % MODULUS


func add_many(numbers: Array[int]) -> void:
	for number: int in numbers:
		add(number)


func add_string(text: String) -> void:
	for code: int in text.to_utf8_buffer():
		add(code)
