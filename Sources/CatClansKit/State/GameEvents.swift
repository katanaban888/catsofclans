import Foundation

/// События, которые возвращают изменения состояния деревни.
/// Интерфейс превращает их в всплывающие подсказки.
public enum GameEvent: Equatable {
    case trainingFinished(UnitID)
    case raidIncoming(String)
    case leveledUp(Int)
}

/// Результат игрового действия (постройка, улучшение, обучение…).
public enum GameResult: Equatable {
    case ok(String)
    case error(String)

    public var message: String {
        switch self {
        case .ok(let m):    return m
        case .error(let m): return m
        }
    }

    public var isSuccess: Bool {
        if case .ok = self { return true }
        return false
    }
}

/// Итог оффлайн-прогресса (пока приложение не запускалось).
public struct OfflineSummary: Equatable {
    public var elapsed: TimeInterval
    public var gained: ResourceAmounts
    public var trained: [UnitID]

    public init(elapsed: TimeInterval, gained: ResourceAmounts, trained: [UnitID]) {
        self.elapsed = elapsed
        self.gained = gained
        self.trained = trained
    }

    public var note: String {
        var parts: [String] = []
        for r in Resource.allCases {
            let v = gained[r]
            if v != 0 {
                parts.append("\(r.emoji) +\(v)")
            }
        }
        var s = "Пока вас не было: "
        s += parts.isEmpty ? "ничего не изменилось" : parts.joined(separator: "  ")
        if !trained.isEmpty {
            let names = trained.map { $0.emoji }.joined(separator: " ")
            s += ". Обучились: \(names)"
        }
        return s
    }
}
