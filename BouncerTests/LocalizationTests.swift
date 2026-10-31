import Foundation
import Testing
@testable import Bouncer

struct LocalizationTests {
    private func bundle(_ language: String) throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    private func volumeCount(_ count: Int, in language: String) throws -> String {
        let format = try bundle(language).localizedString(forKey: "Ejecting removes %lld volumes", value: nil, table: nil)
        return String(format: format, locale: Locale(identifier: language), count)
    }

    /// The app ships in all of these.
    @Test(arguments: ["ar", "de", "es", "fr", "hi", "id", "it", "ja", "ko", "pl", "pt", "ru", "th", "tr", "vi", "zh-Hans"])
    func everyLanguageIsTranslated(language: String) throws {
        let translation = try bundle(language).localizedString(forKey: "No drives to eject", value: "", table: nil)
        #expect(translation != "No drives to eject")
        #expect(translation != "")
    }

    @Test(arguments: [
        ("en", 1, "Ejecting removes 1 volume"),
        ("en", 3, "Ejecting removes all 3 volumes"),
        ("ru", 2, "При извлечении будут отключены все 2 тома"),
        ("ru", 5, "При извлечении будут отключены все 5 томов"),
        ("pl", 2, "Wysunięcie odłączy wszystkie 2 woluminy"),
        ("pl", 5, "Wysunięcie odłączy wszystkie 5 woluminów"),
        ("ar", 2, "سيؤدي الإخراج إلى إزالة وحدتي التخزين كلتيهما"),
    ])
    func volumeCountsUseEachLanguagesPlurals(language: String, count: Int, expected: String) throws {
        #expect(try volumeCount(count, in: language) == expected)
    }
}
