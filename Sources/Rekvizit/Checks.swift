// Контрольные суммы российских реквизитов. Алгоритмы — по открытым описаниям ФНС, ПФР и Банка России.

/// Результат проверки: либо всё верно, либо понятная причина, почему нет.
public enum Verdict: Equatable, Sendable {
    case valid
    case invalid(String)

    public var isValid: Bool { self == .valid }
}

/// Оставляет только цифры: «7707 083-893» и «7707083893» проверяются одинаково.
func digits(_ s: String) -> [Int] {
    s.compactMap { $0.wholeNumberValue }.filter { $0 >= 0 && $0 <= 9 }
}

/// Сумма произведений цифр на веса, как во всех алгоритмах ФНС.
func weighted(_ d: [Int], _ weights: [Int]) -> Int {
    zip(d, weights).reduce(0) { $0 + $1.0 * $1.1 }
}

func onlyDigits(_ s: String) -> Bool {
    let cleaned = s.filter { !" -".contains($0) }
    return !cleaned.isEmpty && cleaned.allSatisfy { $0.isASCII && $0.isNumber }
}

// MARK: - ИНН

/// ИНН организации (10 цифр) или физлица и ИП (12 цифр).
public func checkINN(_ input: String) -> Verdict {
    guard onlyDigits(input) else { return .invalid("ИНН состоит только из цифр") }
    let d = digits(input)
    switch d.count {
    case 10:
        let c = weighted(d, [2, 4, 10, 3, 5, 9, 4, 6, 8]) % 11 % 10
        return c == d[9] ? .valid : .invalid("не сходится контрольная цифра: ожидалась \(c), а стоит \(d[9])")
    case 12:
        let c11 = weighted(d, [7, 2, 4, 10, 3, 5, 9, 4, 6, 8]) % 11 % 10
        let c12 = weighted(d, [3, 7, 2, 4, 10, 3, 5, 9, 4, 6, 8]) % 11 % 10
        if c11 != d[10] { return .invalid("не сходится 11-я цифра: ожидалась \(c11), а стоит \(d[10])") }
        if c12 != d[11] { return .invalid("не сходится 12-я цифра: ожидалась \(c12), а стоит \(d[11])") }
        return .valid
    default:
        return .invalid("в ИНН 10 цифр у организации или 12 у физлица, а здесь \(d.count)")
    }
}

// MARK: - ОГРН и ОГРНИП

/// Остаток от деления длинного числа (до 15 цифр) без переполнения.
func mod(_ d: [Int], _ m: Int) -> Int {
    d.reduce(0) { ($0 * 10 + $1) % m }
}

/// ОГРН (13 цифр) или ОГРНИП (15 цифр).
public func checkOGRN(_ input: String) -> Verdict {
    guard onlyDigits(input) else { return .invalid("ОГРН состоит только из цифр") }
    let d = digits(input)
    switch d.count {
    case 13:
        let c = mod(Array(d[0..<12]), 11) % 10
        return c == d[12] ? .valid : .invalid("не сходится контрольная цифра: ожидалась \(c), а стоит \(d[12])")
    case 15:
        let c = mod(Array(d[0..<14]), 13) % 10
        return c == d[14] ? .valid : .invalid("не сходится контрольная цифра: ожидалась \(c), а стоит \(d[14])")
    default:
        return .invalid("в ОГРН 13 цифр, в ОГРНИП 15, а здесь \(d.count)")
    }
}

// MARK: - СНИЛС

func snilsChecksum(_ d: [Int]) -> Int {
    let s = weighted(d, [9, 8, 7, 6, 5, 4, 3, 2, 1])
    if s < 100 { return s }
    if s == 100 || s == 101 { return 0 }
    let r = s % 101
    return r == 100 ? 0 : r
}

/// СНИЛС: 11 цифр, последние две — контрольное число. Номера до 001-001-998 выдавались без проверки.
public func checkSNILS(_ input: String) -> Verdict {
    guard onlyDigits(input) else { return .invalid("СНИЛС состоит только из цифр, дефисов и пробела") }
    let d = digits(input)
    guard d.count == 11 else { return .invalid("в СНИЛС 11 цифр, а здесь \(d.count)") }
    let number = d[0..<9].reduce(0) { $0 * 10 + $1 }
    if number <= 1_001_998 { return .valid }
    let expected = snilsChecksum(Array(d[0..<9]))
    let actual = d[9] * 10 + d[10]
    return expected == actual
        ? .valid
        : .invalid("не сходится контрольное число: ожидалось \(format2(expected)), а стоит \(format2(actual))")
}

func format2(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }

// MARK: - КПП

/// КПП: 4 цифры кода налоговой, 2 символа причины (цифры или латинские заглавные), 3 цифры номера.
public func checkKPP(_ input: String) -> Verdict {
    let s = Array(input.filter { $0 != " " })
    guard s.count == 9 else { return .invalid("в КПП 9 символов, а здесь \(s.count)") }
    let isDigit = { (c: Character) in c.isASCII && c.isNumber }
    let isReason = { (c: Character) in isDigit(c) || ("A"..."Z").contains(c) }
    guard s[0..<4].allSatisfy(isDigit), s[4..<6].allSatisfy(isReason), s[6..<9].allSatisfy(isDigit) else {
        return .invalid("формат КПП: NNNNPPNNN, где P — цифра или латинская заглавная буква")
    }
    return .valid
}

// MARK: - БИК и счета

/// БИК: 9 цифр, начинается с 04 (Россия).
public func checkBIK(_ input: String) -> Verdict {
    guard onlyDigits(input) else { return .invalid("БИК состоит только из цифр") }
    let d = digits(input)
    guard d.count == 9 else { return .invalid("в БИК 9 цифр, а здесь \(d.count)") }
    guard d[0] == 0 && d[1] == 4 else { return .invalid("российский БИК начинается с 04") }
    return .valid
}

func accountKey(_ d: [Int]) -> Int {
    let weights = [7, 1, 3]
    return d.enumerated().reduce(0) { $0 + ($1.element * weights[$1.offset % 3]) % 10 } % 10
}

/// Расчётный счёт вместе с БИК банка. Ключ — последние 3 цифры БИК + 20 цифр счёта, веса 7-1-3.
public func checkAccount(_ account: String, bik: String) -> Verdict {
    if case .invalid(let why) = checkBIK(bik) { return .invalid("БИК: \(why)") }
    guard onlyDigits(account) else { return .invalid("счёт состоит только из цифр") }
    let a = digits(account)
    guard a.count == 20 else { return .invalid("в счёте 20 цифр, а здесь \(a.count)") }
    let b = digits(bik)
    // Счета в расчётно-кассовых центрах ЦБ (БИК оканчивается на 000–002) считаются от «0» + 5–6 цифры БИК
    let prefix = b[6] == 0 && b[7] == 0 && b[8] <= 2 ? [0, b[4], b[5]] : Array(b[6..<9])
    return accountKey(prefix + a) == 0 ? .valid : .invalid("счёт не подходит к этому БИК: не сходится контрольный ключ")
}

/// Корреспондентский счёт: ключ считается от «0» + 5–6 цифры БИК.
public func checkCorrAccount(_ account: String, bik: String) -> Verdict {
    if case .invalid(let why) = checkBIK(bik) { return .invalid("БИК: \(why)") }
    guard onlyDigits(account) else { return .invalid("счёт состоит только из цифр") }
    let a = digits(account)
    guard a.count == 20 else { return .invalid("в счёте 20 цифр, а здесь \(a.count)") }
    guard a[0] == 3, a[1] == 0, a[2] == 1, a[3] == 0, a[4] == 1 else { return .invalid("корр. счёт начинается с 30101") }
    let b = digits(bik)
    return accountKey([0, b[4], b[5]] + a) == 0 ? .valid : .invalid("корр. счёт не подходит к этому БИК")
}

// MARK: - Банковская карта

/// Номер карты по алгоритму Луна, 13–19 цифр.
public func checkCard(_ input: String) -> Verdict {
    guard onlyDigits(input) else { return .invalid("номер карты состоит только из цифр") }
    let d = digits(input)
    guard (13...19).contains(d.count) else { return .invalid("в номере карты 13–19 цифр, а здесь \(d.count)") }
    let sum = d.reversed().enumerated().reduce(0) { acc, item in
        let x = item.offset % 2 == 1 ? item.element * 2 : item.element
        return acc + (x > 9 ? x - 9 : x)
    }
    return sum % 10 == 0 ? .valid : .invalid("не проходит проверку по алгоритму Луна")
}
