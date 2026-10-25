import XCTest
@testable import Rekvizit

final class ChecksTests: XCTestCase {
    // Реальные открытые реквизиты ПАО Сбербанк и классические примеры из документации
    func testKnownValidNumbers() {
        XCTAssertEqual(checkINN("7707083893"), .valid)
        XCTAssertEqual(checkINN("500100732259"), .valid)
        XCTAssertEqual(checkOGRN("1027700132195"), .valid)
        XCTAssertEqual(checkOGRN("304500116000157"), .valid)
        XCTAssertEqual(checkSNILS("112-233-445 95"), .valid)
        XCTAssertEqual(checkBIK("044525225"), .valid)
        XCTAssertEqual(checkCorrAccount("30101810400000000225", bik: "044525225"), .valid)
        XCTAssertEqual(checkCard("4111 1111 1111 1111"), .valid)
        XCTAssertEqual(checkKPP("773601001"), .valid)
        XCTAssertEqual(checkKPP("7736AB001"), .valid)
    }

    func testFormattingIsIgnored() {
        XCTAssertEqual(checkINN("7707 083 893"), .valid)
        XCTAssertEqual(checkSNILS("11223344595"), .valid)
    }

    func testWrongCheckDigitExplainsWhy() {
        guard case .invalid(let why) = checkINN("7707083894") else { return XCTFail() }
        XCTAssertTrue(why.contains("ожидалась 3"), why)
        guard case .invalid(let why12) = checkINN("500100732258") else { return XCTFail() }
        XCTAssertTrue(why12.contains("12-я"), why12)
        XCTAssertFalse(checkOGRN("1027700132194").isValid)
        XCTAssertFalse(checkSNILS("112-233-445 96").isValid)
        XCTAssertFalse(checkCard("4111 1111 1111 1112").isValid)
    }

    func testLengthAndFormatErrors() {
        guard case .invalid(let why) = checkINN("12345") else { return XCTFail() }
        XCTAssertTrue(why.contains("здесь 5"), why)
        XCTAssertFalse(checkINN("77070838a3").isValid)
        XCTAssertFalse(checkBIK("123456789").isValid)
        XCTAssertFalse(checkKPP("7736ab001").isValid)
        XCTAssertFalse(checkCorrAccount("40702810400000000225", bik: "044525225").isValid)
    }

    func testOldSnilsAreNotChecked() {
        // До 001-001-998 контрольное число не рассчитывалось
        XCTAssertEqual(checkSNILS("001-001-997 00"), .valid)
    }

    func testSnilsChecksumEdgeCases() {
        // сумма 100 или 101 даёт 00, больше 101 — остаток от деления на 101
        XCTAssertEqual(snilsChecksum([0, 0, 0, 0, 0, 0, 0, 0, 0]), 0)
        XCTAssertEqual(snilsChecksum([1, 1, 1, 1, 1, 1, 1, 1, 1]), 45)
        XCTAssertEqual(snilsChecksum([9, 9, 9, 9, 9, 9, 9, 9, 9]), 405 % 101)
    }
}

final class DetectTests: XCTestCase {
    func testDetectsByLength() {
        XCTAssertEqual(detect("7707083893").map(\.kind), [.inn10])
        XCTAssertEqual(detect("500100732259").map(\.kind), [.inn12])
        XCTAssertEqual(detect("112-233-445 95").map(\.kind), [.snils])
        XCTAssertEqual(detect("304500116000157").map(\.kind), [.ogrnip])
        XCTAssertEqual(detect("4111111111111111").map(\.kind), [.card])
    }

    func testNineDigitsCanBeBikOrKpp() {
        XCTAssertEqual(detect("044525225").map(\.kind), [.bik, .kpp])
        XCTAssertEqual(detect("773601001").map(\.kind), [.kpp])
        XCTAssertEqual(detect("7736AB001").map(\.kind), [.kpp])
    }

    func testGarbageIsNotDetected() {
        XCTAssertTrue(detect("привет").isEmpty)
        XCTAssertTrue(detect("12345").isEmpty)
    }
}

final class GeneratorTests: XCTestCase {
    func testEveryGeneratedNumberIsValid() {
        var gen = Generator(rng: SeededRandom(seed: 42))
        for kind in Kind.allCases {
            for _ in 0..<500 {
                let n = gen.make(kind)
                let found = detect(n)
                XCTAssertTrue(found.contains { $0.kind == kind && $0.verdict.isValid }, "\(kind): \(n) -> \(found)")
            }
        }
    }

    func testGeneratedAccountMatchesBik() {
        var gen = Generator(rng: SeededRandom(seed: 7))
        for bik in ["044525225", "044030653", "045004001"] {
            for _ in 0..<200 {
                let acc = gen.account(for: bik)
                XCTAssertEqual(checkAccount(acc, bik: bik), .valid, "\(acc) @ \(bik)")
                XCTAssertTrue(acc.hasPrefix("40702810"))
            }
        }
    }

    func testAnySingleDigitChangeBreaksAccount() {
        var gen = Generator(rng: SeededRandom(seed: 1))
        let bik = "044525225"
        let acc = Array(gen.account(for: bik))
        for i in acc.indices {
            var broken = acc
            let d = acc[i].wholeNumberValue!
            broken[i] = Character(String((d + 1) % 10))
            XCTAssertFalse(checkAccount(String(broken), bik: bik).isValid, "позиция \(i)")
        }
    }

    func testSeedMakesOutputRepeatable() {
        var a = Generator(rng: SeededRandom(seed: 99))
        var b = Generator(rng: SeededRandom(seed: 99))
        XCTAssertEqual((0..<20).map { _ in a.make(.inn12) }, (0..<20).map { _ in b.make(.inn12) })
    }
}
