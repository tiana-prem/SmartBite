import Foundation

struct Recipe: Identifiable, Decodable {
    let id: String
    let name: String
    let category: String
    let imageURL: URL?
    let sourceURL: URL?
    let instructions: String
    let ingredients: [Ingredient]
    var providerName: String = "TheMealDB"

    init(id: String, name: String, category: String, imageURL: URL?, sourceURL: URL?, instructions: String, ingredients: [Ingredient], providerName: String) {
        self.id = id; self.name = name; self.category = category
        self.imageURL = imageURL; self.sourceURL = sourceURL
        self.instructions = instructions; self.ingredients = ingredients
        self.providerName = providerName
    }

    struct Ingredient: Identifiable {
        var id: String { name }
        let name: String
        let measure: String
    }

    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(_ value: String) { stringValue = value }
        init?(stringValue: String) { self.init(stringValue) }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: Key.self)
        func text(_ key: String) -> String {
            (try? values.decodeIfPresent(String.self, forKey: Key(key)))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        id = text("idMeal")
        name = text("strMeal")
        category = text("strCategory")
        imageURL = URL(string: text("strMealThumb"))
        let source = URL(string: text("strSource"))
        sourceURL = ["http", "https"].contains(source?.scheme ?? "") ? source : URL(string: "https://www.themealdb.com/meal/\(id)")
        instructions = text("strInstructions")
        ingredients = (1...20).compactMap { index in
            let name = text("strIngredient\(index)")
            return name.isEmpty ? nil : Ingredient(name: name, measure: text("strMeasure\(index)"))
        }
    }

    func canMake(with pantry: [String]) -> Bool {
        let available = Set(pantry.map(IngredientNames.normalize))
        return !ingredients.isEmpty && ingredients.allSatisfy { available.contains(IngredientNames.normalize($0.name)) }
    }
}

enum IngredientNames {
    static func normalize(_ value: String) -> String {
        let cleaned = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        // Explicit aliases avoid treating different foods (e.g. milk and coconut milk) as interchangeable.
        let aliases = ["tomatoes": "tomato", "potatoes": "potato", "eggs": "egg", "onions": "onion",
                       "carrots": "carrot", "mushrooms": "mushroom", "lemons": "lemon", "limes": "lime",
                       "apples": "apple", "bananas": "banana", "pears": "pear", "garlic clove": "garlic",
                       "garlic cloves": "garlic", "cloves garlic": "garlic", "spring onions": "spring onion",
                       "scallions": "spring onion", "green onions": "spring onion", "chickpeas": "chickpea",
                       "garbanzo beans": "chickpea", "aubergine": "eggplant", "courgette": "zucchini",
                       "chicken breasts": "chicken breast", "chicken thighs": "chicken thigh"]
        return aliases[cleaned] ?? cleaned
    }

    static func parse(_ text: String) -> [String] {
        var seen = Set<String>()
        return text.components(separatedBy: CharacterSet(charactersIn: ",\n;"))
            .map(normalize).filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

@MainActor
final class RecipeService {
    static let shared = RecipeService()
    private var cached: [Recipe]?
    private var pending: Task<[Recipe], Error>?
    private struct Response: Decodable { let meals: [Recipe]? }

    func recipes() async throws -> [Recipe] {
        if let cached { return cached }
        if let pending { return try await pending.value }
        let task = Task { () throws -> [Recipe] in
            var recipes: [Recipe] = []
            // Full details are needed: an ingredient filter alone cannot prove a recipe is cookable.
            for letter in "abcdefghijklmnopqrstuvwxyz" {
                try Task.checkCancellation()
                let url = URL(string: "https://www.themealdb.com/api/json/v1/1/search.php?f=\(letter)")!
                let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 20))
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                recipes += try JSONDecoder().decode(Response.self, from: data).meals ?? []
            }
            var seen = Set<String>()
            return recipes.filter { seen.insert($0.id).inserted }.sorted { $0.name < $1.name }
        }
        pending = task
        defer { pending = nil }
        let result = try await task.value
        cached = result
        return result
    }
}
