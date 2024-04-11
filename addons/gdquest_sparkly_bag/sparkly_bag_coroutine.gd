class Inner:
	signal finished

	var _count := 0

	func _init(count: int) -> void:
		_count = count

	func check() -> void:
		_count -= 1
		if _count == 0:
			finished.emit()


static func parallel(coroutines: Array[Callable]) -> Array:
	var results := []
	var inner := Inner.new(coroutines.size())
	for coroutine in coroutines.map(
		func(coroutine: Callable) -> Callable: return func() -> void:
			results.push_back(await coroutine.call())
			inner.check()
	):
		coroutine.call()
	await inner.finished
	return results


static func sequence(coroutines: Array[Callable]) -> Array:
	var result := []
	for coroutine in coroutines:
		result.push_back(await coroutine.call())
	return result
