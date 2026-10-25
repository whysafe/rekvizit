import Foundation
import Rekvizit

let usage = """
rekvizit — проверка и генерация российских реквизитов

  rekvizit НОМЕР [НОМЕР ...]           определить тип и проверить
  rekvizit счёт СЧЁТ БИК               проверить расчётный счёт вместе с БИК
  rekvizit gen ВИД [КОЛИЧЕСТВО]        сгенерировать корректные тестовые номера
  rekvizit gen счёт БИК [КОЛИЧЕСТВО]   счёт, который сойдётся с этим БИК
  -                                    читать номера из stdin, по одному в строке

Виды: \(Kind.allCases.map(\.rawValue).joined(separator: ", "))
Код выхода 1, если хотя бы один номер не прошёл проверку.
"""

func line(_ input: String, _ kind: String, _ v: Verdict) -> String {
    switch v {
    case .valid: return "✓ \(input)  \(kind)"
    case .invalid(let why): return "✗ \(input)  \(kind): \(why)"
    }
}

func checkAll(_ inputs: [String]) -> Int32 {
    var failed = false
    for raw in inputs where !raw.trimmedForCLI.isEmpty {
        let input = raw.trimmedForCLI
        let found = detect(input)
        if found.isEmpty {
            print("? \(input)  не похоже ни на один реквизит (длина \(input.filter(\.isNumber).count))")
            failed = true
            continue
        }
        // Если вариантов несколько (9 цифр: БИК или КПП), номер верен, если подходит хотя бы под один
        if !found.contains(where: { $0.verdict.isValid }) { failed = true }
        for d in found { print(line(input, d.kind.title, d.verdict)) }
    }
    return failed ? 1 : 0
}

extension String {
    var trimmedForCLI: String {
        var s = Substring(self)
        while let f = s.first, f.isWhitespace { s.removeFirst() }
        while let l = s.last, l.isWhitespace { s.removeLast() }
        return String(s)
    }
}

var args = Array(CommandLine.arguments.dropFirst())
if args.isEmpty || args.contains("-h") || args.contains("--help") {
    print(usage)
    exit(args.isEmpty ? 2 : 0)
}

switch args[0] {
case "gen":
    var gen = Generator()
    guard args.count >= 2 else { print(usage); exit(2) }
    if args[1] == "счёт" || args[1] == "account" {
        guard args.count >= 3, checkBIK(args[2]).isValid else {
            print("Укажите корректный БИК: rekvizit gen счёт 044525225")
            exit(2)
        }
        let n = args.count >= 4 ? Int(args[3]) ?? 1 : 1
        for _ in 0..<max(1, n) { print(gen.account(for: args[2])) }
        exit(0)
    }
    guard let kind = Kind(rawValue: args[1]) else {
        print("Неизвестный вид «\(args[1])». Есть: \(Kind.allCases.map(\.rawValue).joined(separator: ", "))")
        exit(2)
    }
    let n = args.count >= 3 ? Int(args[2]) ?? 1 : 1
    for _ in 0..<min(max(1, n), 10_000) { print(gen.make(kind)) }
case "счёт", "account":
    guard args.count == 3 else { print(usage); exit(2) }
    let v = checkAccount(args[1], bik: args[2])
    print(line(args[1], "расчётный счёт при БИК \(args[2])", v))
    exit(v.isValid ? 0 : 1)
case "-":
    var lines: [String] = []
    while let l = readLine() { lines.append(l) }
    exit(checkAll(lines))
default:
    exit(checkAll(args))
}
