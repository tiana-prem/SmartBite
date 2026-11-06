import Foundation
import Security

struct RecipeMatch: Identifiable {
    var id: String { recipe.id }
    let recipe: Recipe
    let missing: [String]
    let usedCount: Int
}

// Keep provider-specific JSON and authentication out of the views.
@MainActor
protocol RecipeProvider {
    func search(ingredients: [String]) async throws -> [RecipeMatch]
}

struct MealDBProvider: RecipeProvider {
    func search(ingredients: [String]) async throws -> [RecipeMatch] {
        let available = Set(ingredients.map(IngredientNames.normalize))
        return try await RecipeService.shared.recipes().compactMap { recipe in
            let missing = recipe.ingredients.filter { !available.contains(IngredientNames.normalize($0.name)) }.map(\.name)
            let used = recipe.ingredients.count - missing.count
            guard used > 0, missing.count <= 2 else { return nil }
            return RecipeMatch(recipe: recipe, missing: missing, usedCount: used)
        }.sorted {
            if $0.missing.count != $1.missing.count { return $0.missing.count < $1.missing.count }
            if $0.usedCount != $1.usedCount { return $0.usedCount > $1.usedCount }
            return $0.recipe.name < $1.recipe.name
        }
    }
}

struct SpoonacularProvider: RecipeProvider {
    let apiKey: String

    struct Item: Decodable {
        let name: String
        let original: String?
    }
    struct SearchResult: Decodable {
        let id: Int
        let title: String
        let image: String?
        let usedIngredientCount: Int
        let missedIngredientCount: Int
        let missedIngredients: [Item]
        let usedIngredients: [Item]
    }
    struct Detail: Decodable {
        let id: Int
        let title: String
        let image: String?
        let sourceUrl: String?
        let extendedIngredients: [Item]
        let analyzedInstructions: [Instruction]?
        struct Instruction: Decodable {
            let steps: [Step]
            struct Step: Decodable { let number: Int; let step: String }
        }
    }

    func search(ingredients: [String]) async throws -> [RecipeMatch] {
        let data = try await request(path: "findByIngredients", query: [
            URLQueryItem(name: "ingredients", value: ingredients.joined(separator: ",")),
            URLQueryItem(name: "number", value: "100"),
            URLQueryItem(name: "ranking", value: "2"),
            URLQueryItem(name: "ignorePantry", value: "false")
        ])
        return try JSONDecoder().decode([SearchResult].self, from: data)
            .filter { $0.usedIngredientCount > 0 && $0.missedIngredientCount <= 2 }
            .map { item in
                RecipeMatch(recipe: Recipe(id: String(item.id), name: item.title, category: "",
                    imageURL: URL(string: item.image ?? ""), sourceURL: nil, instructions: "",
                    ingredients: (item.usedIngredients + item.missedIngredients).map { .init(name: $0.name, measure: $0.original ?? "") },
                    providerName: "Spoonacular"), missing: item.missedIngredients.map(\.name), usedCount: item.usedIngredientCount)
            }.sorted {
                if $0.missing.count != $1.missing.count { return $0.missing.count < $1.missing.count }
                return $0.usedCount > $1.usedCount
            }
    }

    func detail(id: String) async throws -> Recipe {
        let data = try await request(path: "\(id)/information", query: [])
        let item = try JSONDecoder().decode(Detail.self, from: data)
        let instructions = (item.analyzedInstructions ?? []).flatMap(\.steps)
            .map { "\($0.number). \($0.step)" }.joined(separator: "\n\n")
        let source = URL(string: item.sourceUrl ?? "")
        return Recipe(id: String(item.id), name: item.title, category: "",
            imageURL: URL(string: item.image ?? ""), sourceURL: ["https", "http"].contains(source?.scheme ?? "") ? source : nil,
            instructions: instructions.isEmpty ? "Open the original recipe for cooking instructions." : instructions,
            ingredients: item.extendedIngredients.map { .init(name: $0.name, measure: $0.original ?? "") }, providerName: "Spoonacular")
    }

    private func request(path: String, query: [URLQueryItem]) async throws -> Data {
        guard !apiKey.isEmpty else { throw ProviderError.message("Add your Spoonacular API key in Recipe source to search.") }
        var components = URLComponents(string: "https://api.spoonacular.com/recipes/\(path)")!
        components.queryItems = query
        var request = URLRequest(url: components.url!, timeoutInterval: 25)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        switch http.statusCode {
        case 200...299: return data
        case 401, 403: throw ProviderError.message("Spoonacular rejected this key. Check it in Recipe source.")
        case 402, 429: throw ProviderError.message("Spoonacular’s request allowance has been reached. Try later or check your plan.")
        default: throw ProviderError.message("Spoonacular is unavailable right now. Please try again.")
        }
    }
}

enum ProviderError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

enum RecipeKeyStore {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "SmartBite.Spoonacular", kSecAttrAccount as String: "apiKey"]
    }
    static func read() -> String {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static func save(_ value: String) throws {
        let data = Data(value.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var request = query
            request[kSecValueData as String] = data
            request[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(request as CFDictionary, nil) == errSecSuccess else { throw ProviderError.message("Couldn’t save the key securely. Please try again.") }
        } else if status != errSecSuccess { throw ProviderError.message("Couldn’t update the saved key.") }
    }
}
