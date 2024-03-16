import Foundation
import StringCatalog

let jsonString = """
{
  "sourceLanguage" : "en",
  "strings" : {
    "Use this model to transcribe" : {

    },

    "Your clipboard does not change" : {

    },
    "bla bla" : {
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "bla bla"
          }
        },
        "fr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "bla bla"
          }
        }
      }
    },
  },
  "version" : "1.0"
}
"""

//let jsonData = jsonString.data(using: .utf8)!
let json = try String(contentsOf: URL(filePath: "/Users/atacan/Documents/myway/Repositories/dipdict_libraries/Sources/Settings/Resources/Localizable.xcstrings"))
let jsonData = json.data(using: .utf8)!


let decoder = JSONDecoder()
var catalog = try decoder.decode(StringCatalog.self, from: jsonData)
print("Source Language: \(catalog.sourceLanguage)")
//print("Version: \(catalog.version)")
// Now you can access `catalog.strings` dictionary and each string with its localizations.
//    dump(catalog)

func encodeCatalogToString(catalog: StringCatalog) throws -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  
  let encodedData = try encoder.encode(catalog)
  return String(data: encodedData, encoding: .utf8)!
}


func translate(text: String, comment: String? = nil) async throws  -> String {
    return "Translating [\(text)] using comment: [\(comment ?? "NO COMMENT")]"
}

import ConcurrencyExtras

func translateCatalog(catalog: StringCatalog) async throws -> StringCatalog {
    let catalogIsolated = ActorIsolated(catalog)
    await withThrowingTaskGroup(of: Void.self) { group in
        for index in catalog.strings.indices {
            group.addTask {
                let key = catalog.strings.keys[index]
                let value = catalog.strings.values[index]
                let translation = try await translate(text: key, comment: value.comment)
                await catalogIsolated.withValue {
                    $0.strings[key]?.localizations?[.german] = StringLocalization(stringUnit: .init(state: .translated, value: translation))
                }
            }
        }
    }
    return await catalogIsolated.value
}

let encodedCatalog = try encodeCatalogToString(catalog: catalog)
print(encodedCatalog)

