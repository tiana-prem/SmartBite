import SwiftUI

struct IngredientPortrait: View {
    let name: String
    var size: CGFloat = 48
    private var url: URL? {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return URL(string: "https://www.themealdb.com/images/ingredients/\(encoded)-Small.png")
    }
    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit().padding(5)
            } else {
                Text(String(name.prefix(1)).uppercased()).font(.system(size: size * 0.35, weight: .medium)).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(Color(.secondarySystemBackground), in: Circle())
        .clipShape(Circle()).accessibilityHidden(true)
    }
}

struct IngredientsView: View {
    let images: [IdentifiableImage]
    @State private var ingredients: [String] = []
    @State private var entry = ""
    @State private var filter = ""
    @State private var isIdentifying = false
    @State private var hasStarted = false
    @State private var identificationError: String?
    @FocusState private var entryFocused: Bool
    private let accent = Color(red: 0.12, green: 0.32, blue: 0.24)
    private var visibleIngredients: [String] {
        ingredients.filter { filter.isEmpty || $0.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Find an added ingredient", text: $filter)
                if !filter.isEmpty {
                    Button { filter = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(14).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 20).padding(.bottom, 16)

            HStack(spacing: 12) {
                IngredientPortrait(name: "pear", size: 54)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Add ingredients").font(.subheadline.weight(.semibold))
                    TextField("e.g. eggs, milk, flour", text: $entry)
                        .textInputAutocapitalization(.never).submitLabel(.done)
                        .focused($entryFocused).onSubmit(addIngredients)
                }
                Button(action: addIngredients) {
                    Image(systemName: "plus").font(.title3.weight(.medium))
                        .frame(width: 44, height: 44).background(accent, in: Circle()).foregroundStyle(.white)
                }.disabled(IngredientNames.parse(entry).isEmpty)
                    .opacity(IngredientNames.parse(entry).isEmpty ? 0.45 : 1)
                    .accessibilityLabel("Add ingredients")
            }
            .padding(14).background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)

            HStack {
                Text("Added ingredients").font(.headline)
                Text("\(ingredients.count)").foregroundStyle(.secondary)
                Spacer()
            }.padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 0) {
                    if isIdentifying { ProgressView("Identifying ingredients…").padding() }
                    if let identificationError {
                        Text(identificationError).font(.subheadline).foregroundStyle(.secondary).padding(.vertical)
                        Button("Retry photo") { Task { await identify() } }.disabled(isIdentifying)
                    }
                    if visibleIngredients.isEmpty {
                        Text(ingredients.isEmpty ? "Add items above or use the Scan tab." : "No ingredients match your search.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 20)
                    }
                    ForEach(visibleIngredients, id: \.self) { ingredient in
                        HStack(spacing: 14) {
                            IngredientPortrait(name: ingredient)
                            Text(ingredient.capitalized).font(.body)
                            Spacer()
                            Button { ingredients.removeAll { $0 == ingredient } } label: {
                                Image(systemName: "minus.circle").foregroundStyle(.secondary).frame(width: 44, height: 44)
                            }.accessibilityLabel("Remove \(ingredient)")
                        }.padding(.vertical, 10)
                        Divider().padding(.leading, 62)
                    }
                }.padding(.horizontal, 20)
            }.scrollDismissesKeyboard(.interactively)
        }
        .background(Color(.systemBackground))
        .safeAreaInset(edge: .bottom) {
            NavigationLink { RecipeResultsView(ingredients: ingredients) } label: {
                HStack {
                    Text("Find recipes").fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "arrow.right")
                }.padding(17).background(accent, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
            }
            .disabled(ingredients.isEmpty).opacity(ingredients.isEmpty ? 0.45 : 1)
            .padding(.horizontal, 20).padding(.vertical, 10).background(Color(.systemBackground))
        }
        .navigationTitle("Ingredients").navigationBarTitleDisplayMode(.inline)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            if !images.isEmpty { await identify() }
        }
    }

    private func addIngredients() {
        ingredients = IngredientNames.parse((ingredients + [entry]).joined(separator: ","))
        entry = ""
        filter = ""
        entryFocused = false
    }

    private func identify() async {
        isIdentifying = true
        identificationError = nil
        defer { isIdentifying = false }
        let result = await ingredientIdentify().analyzeObject(images: images)
        guard !Task.isCancelled else { return }
        if result.lowercased().hasPrefix("error") || ["unknown", "unkonwn"].contains(result.lowercased()) {
            identificationError = "Couldn’t identify these photos. Check that your local AI server is running, or enter ingredients manually."
        } else {
            let detected = IngredientNames.parse(result)
            if detected.isEmpty { identificationError = "No ingredients were identified. Try another photo or add them manually." }
            ingredients = IngredientNames.parse((ingredients + detected).joined(separator: ","))
        }
    }

}

struct RecipeDetailView: View {
    let recipe: Recipe
    var body: some View {
        List {
            Section {
                AsyncImage(url: recipe.imageURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: { ProgressView() }
                Text(recipe.name).font(.title.bold())
                Text(recipe.category).foregroundStyle(.secondary)
            }
            Section("Ingredients") {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, ingredient in
                    HStack {
                        Text(ingredient.name.capitalized)
                        Spacer()
                        Text(ingredient.measure).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Instructions") { Text(recipe.instructions) }
            Section {
                if let source = recipe.sourceURL { Link("View original recipe", destination: source) }
                Text("Recipe provided by \(recipe.providerName)").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Recipe").navigationBarTitleDisplayMode(.inline)
    }
}
