// Поддерживающие утилиты ядра.

/// Детерминированный 64-битный генератор случайных чисел (SplitMix64).
///
/// Один и тот же seed всегда даёт одну и ту же последовательность,
/// поэтому бои воспроизводимы и их можно проверять тестами.
public struct SeededRNG {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        // Ноль заменяем на константу, чтобы не «залипать» на нулевой цепочке.
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Целое в диапазоне 0..<n. n обязательно положительное.
    public mutating func nextInt(_ n: Int) -> Int {
        precondition(n > 0, "SeededRNG.nextInt: n должен быть > 0")
        return Int(next() % UInt64(n))
    }

    /// Целое в диапазоне a...b (включительно).
    public mutating func int(_ a: Int, _ b: Int) -> Int {
        precondition(a <= b, "SeededRNG.int: a > b")
        return a + nextInt(b - a + 1)
    }

    /// Дробное в диапазоне a...b.
    public mutating func double(_ a: Double, _ b: Double) -> Double {
        // 2^-53 — точный обратный к 2^53. Оператора ** в stdlib Swift нет,
        // поэтому пишем явную степень двойки через деление (поведение идентично).
        let unit = Double(next() >> 11) * (1.0 / 9007199254740992.0) // [0, 1)
        return a + unit * (b - a)
    }

    /// Случайный элемент массива.
    public mutating func pick<T>(_ items: [T]) -> T {
        precondition(!items.isEmpty, "SeededRNG.pick: пустой массив")
        return items[nextInt(items.count)]
    }

    /// true с вероятностью p (0...1).
    public mutating func chance(_ p: Double) -> Bool {
        return double(0, 1) < p
    }
}
