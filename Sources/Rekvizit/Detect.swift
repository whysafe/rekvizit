/// Виды реквизитов, которые умеет проверять и генерировать библиотека.
public enum Kind: String, CaseIterable, Sendable {
    case inn10, inn12, ogrn, ogrnip, snils, kpp, bik, card

    public var title: String {
        switch self {
        case .inn10: return "ИНН организации"
        case .inn12: return "ИНН физлица или ИП"
        case .ogrn: return "ОГРН"
        case .ogrnip: return "ОГРНИП"
        case .snils: return "СНИЛС"
        case .kpp: return "КПП"
        case .bik: return "БИК"
        case .card: return "Номер карты"
        }
    }
}

public struct Detection: Equatable, Sendable {
    public let kind: Kind
    public let verdict: Verdict
}

/// Угадывает, что за номер, по длине и формату, и сразу проверяет его.
///
/// Длина однозначна почти везде. Исключение — 9 цифр: это КПП или БИК. БИК начинается
/// с 04, но и КПП налоговой с кодом 04xx бывает, поэтому для 9 цифр возвращаются оба варианта.
public func detect(_ input: String) -> [Detection] {
    let trimmed = input.trimmedSpaces
    let compact = trimmed.filter { !" -".contains($0) }
    let d = digits(trimmed)
    var out: [Detection] = []

    if compact.count == 9 && !onlyDigits(trimmed) {
        out.append(Detection(kind: .kpp, verdict: checkKPP(trimmed)))
        return out
    }
    guard onlyDigits(trimmed) else { return [] }
    switch d.count {
    case 9:
        if d[0] == 0 && d[1] == 4 { out.append(Detection(kind: .bik, verdict: checkBIK(trimmed))) }
        out.append(Detection(kind: .kpp, verdict: checkKPP(compact)))
    case 10: out.append(Detection(kind: .inn10, verdict: checkINN(trimmed)))
    case 11: out.append(Detection(kind: .snils, verdict: checkSNILS(trimmed)))
    case 12: out.append(Detection(kind: .inn12, verdict: checkINN(trimmed)))
    case 13: out.append(Detection(kind: .ogrn, verdict: checkOGRN(trimmed)))
    case 15: out.append(Detection(kind: .ogrnip, verdict: checkOGRN(trimmed)))
    default: break
    }
    // 13–19 цифр может быть и номером карты: 13 цифр совпадает с ОГРН, поэтому карту добавляем вторым вариантом
    if (13...19).contains(d.count) && checkCard(trimmed).isValid {
        out.append(Detection(kind: .card, verdict: .valid))
    }
    return out
}

extension String {
    /// Обрезка пробелов по краям без Foundation, чтобы библиотека не тянула зависимостей.
    var trimmedSpaces: String {
        var s = Substring(self)
        while let f = s.first, f.isWhitespace { s.removeFirst() }
        while let l = s.last, l.isWhitespace { s.removeLast() }
        return String(s)
    }
}
