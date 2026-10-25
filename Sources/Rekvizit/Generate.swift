/// Генератор случайных, но корректных по контрольной сумме номеров — для тестовых данных и форм.
///
/// Номера не сверяются с реестрами: это только правильная структура и контрольные цифры,
/// совпадение с настоящей организацией случайно. Для повторяемых тестов передайте генератор с seed.
public struct Generator<R: RandomNumberGenerator> {
    var rng: R

    public init(rng: R) { self.rng = rng }

    mutating func randomDigits(_ n: Int) -> [Int] {
        (0..<n).map { _ in Int.random(in: 0...9, using: &rng) }
    }

    /// Код региона 01–92 в начале ИНН и ОГРН, чтобы номер выглядел правдоподобно.
    mutating func region() -> [Int] {
        let r = Int.random(in: 1...92, using: &rng)
        return [r / 10, r % 10]
    }

    public mutating func make(_ kind: Kind) -> String {
        switch kind {
        case .inn10:
            var d = region() + randomDigits(7)
            d.append(weighted(d, [2, 4, 10, 3, 5, 9, 4, 6, 8]) % 11 % 10)
            return str(d)
        case .inn12:
            var d = region() + randomDigits(8)
            d.append(weighted(d, [7, 2, 4, 10, 3, 5, 9, 4, 6, 8]) % 11 % 10)
            d.append(weighted(d, [3, 7, 2, 4, 10, 3, 5, 9, 4, 6, 8]) % 11 % 10)
            return str(d)
        case .ogrn:
            // 1 или 5 — признак ОГРН, затем две цифры года, регион, остальное
            var d = [Int.random(in: 0...1, using: &rng) == 0 ? 1 : 5] + randomDigits(2) + region() + randomDigits(7)
            d.append(mod(d, 11) % 10)
            return str(d)
        case .ogrnip:
            var d = [3] + randomDigits(2) + region() + randomDigits(9)
            d.append(mod(d, 13) % 10)
            return str(d)
        case .snils:
            var d: [Int]
            repeat { d = randomDigits(9) } while d.reduce(0, { $0 * 10 + $1 }) <= 1_001_998
            let c = snilsChecksum(d)
            let s = str(d) + format2(c)
            // Привычный вид: 123-456-789 01
            let a = Array(s)
            return "\(String(a[0..<3]))-\(String(a[3..<6]))-\(String(a[6..<9])) \(String(a[9..<11]))"
        case .kpp:
            return str(region() + randomDigits(2) + [0, 1] + randomDigits(3))
        case .bik:
            return str([0, 4] + region() + randomDigits(2) + [Int.random(in: 0...9, using: &rng), Int.random(in: 0...9, using: &rng), Int.random(in: 3...9, using: &rng)])
        case .card:
            // 2200–2204 — диапазон «Мир»
            var d = [2, 2, 0, 0 + Int.random(in: 0...4, using: &rng)] + randomDigits(11)
            let sum = d.reversed().enumerated().reduce(0) { acc, item in
                let x = item.offset % 2 == 0 ? item.element * 2 : item.element
                return acc + (x > 9 ? x - 9 : x)
            }
            d.append((10 - sum % 10) % 10)
            return str(d)
        }
    }

    /// Расчётный счёт, который сойдётся с указанным БИК. Счёт юрлица в рублях начинается с 40702810.
    public mutating func account(for bik: String) -> String {
        let b = digits(bik)
        let prefix = b[6] == 0 && b[7] == 0 && b[8] <= 2 ? [0, b[4], b[5]] : Array(b[6..<9])
        var a = [4, 0, 7, 0, 2, 8, 1, 0] + [0] + randomDigits(11)
        // Девятая цифра счёта — контрольный ключ: подбираем её
        for k in 0...9 {
            a[8] = k
            if accountKey(prefix + a) == 0 { break }
        }
        return str(a)
    }

    func str(_ d: [Int]) -> String { d.map(String.init).joined() }
}

public extension Generator where R == SystemRandomNumberGenerator {
    init() { self.init(rng: SystemRandomNumberGenerator()) }
}

/// Простой детерминированный генератор (SplitMix64) для воспроизводимых тестов.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
