import Foundation

public enum SafetensorsMetadataParser {
    public static func languageModelKeyShapes(from data: Data) throws -> [String: [Int]] {
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = jsonObject as? [String: Any] else {
            throw ParserError.invalidRoot
        }

        var keyShapes: [String: [Int]] = [:]
        for (key, value) in dictionary {
            guard key.hasPrefix("model.language_model.") || key.hasPrefix("language_model.") else {
                continue
            }

            guard let entry = value as? [String: Any], let shape = entry["shape"] as? [Any] else {
                continue
            }

            let parsedShape = shape.compactMap { element -> Int? in
                if let intValue = element as? Int {
                    return intValue
                }
                if let numberValue = element as? NSNumber {
                    return numberValue.intValue
                }
                if let stringValue = element as? String, let intValue = Int(stringValue) {
                    return intValue
                }
                return nil
            }

            guard parsedShape.count == shape.count else {
                continue
            }

            keyShapes[key] = parsedShape
        }

        return keyShapes
    }

    public enum ParserError: Error {
        case invalidRoot
    }
}
