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

do {
    let decoder = JSONDecoder()
    let catalog = try decoder.decode(StringCatalog.self, from: jsonData)
    print("Source Language: \(catalog.sourceLanguage)")
    print("Version: \(catalog.version)")
    // Now you can access `catalog.strings` dictionary and each string with its localizations.
    dump(catalog)
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    
    let encodedData = try encoder.encode(catalog)
    print(String(data: encodedData, encoding: .utf8)!)
} catch {
    print(error)
}

