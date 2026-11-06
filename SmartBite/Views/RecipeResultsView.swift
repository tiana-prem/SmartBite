import SwiftUI

struct RecipeResultsView: View {
    let ingredients: [String]
    @AppStorage("recipeProvider") private var provider = "TheMealDB"
    @State private var matches: [RecipeMatch] = []
    @State private var loading = true
    @State private var error: String?
    @State private var showSettings = false
    @State private var revision = UUID()
    @State private var showNearMatches = false
    @State private var completedRevision: UUID?

    private var complete: [RecipeMatch] { matches.filter { $0.missing.isEmpty } }
    private var near: [RecipeMatch] { matches.filter { !$0.missing.isEmpty } }

    var body: some View {
        List {
            Section {
                HStack {
                    Text(provider)
                    Spacer()
                    Button("Change") { showSettings = true }
                }
                if provider == "TheMealDB" {
                    Text("Using the smaller recipe collection. Connect Spoonacular for broader search.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if loading {
                ProgressView("Finding recipes…")
            } else if let error {
                Section {
                    Text(error).foregroundStyle(.secondary)
                    Button("Try again") { revision = UUID() }
                    if provider == "Spoonacular" { Button("Recipe source") { showSettings = true } }
                }
            } else {
                Section("You can make · \(complete.count)") {
                    if complete.isEmpty { Text("No complete matches found.").foregroundStyle(.secondary) }
                    ForEach(complete) { match in row(match) }
                }
                if !near.isEmpty {
                    Section {
                        DisclosureGroup("Missing 1–2 ingredients · \(near.count)", isExpanded: $showNearMatches) {
                            ForEach(near) { match in row(match) }
                        }
                    }
                }
                Section {
                    Text("Ingredient matches don’t check quantities. No pantry basics are assumed.")
                        .font(.caption).foregroundStyle(.secondary)
                    Link("Recipes from \(provider)", destination: URL(string: provider == "Spoonacular" ? "https://spoonacular.com" : "https://www.themealdb.com")!)
                }
            }
        }
        .navigationTitle("Recipes").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSettings, onDismiss: { revision = UUID() }) { RecipeSourceView() }
        .task(id: revision) {
            if completedRevision != revision { await search() }
        }
    }

    private func row(_ match: RecipeMatch) -> some View {
        NavigationLink {
            if match.recipe.providerName == "Spoonacular" {
                SpoonacularDetailView(id: match.id)
            } else { RecipeDetailView(recipe: match.recipe) }
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: match.recipe.imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: { Color(.secondarySystemBackground).overlay(Image(systemName: "fork.knife")) }
                .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 5) {
                    Text(match.recipe.name).font(.body.weight(.medium))
                    Text(match.missing.isEmpty ? "All ingredients available" : "Missing: \(match.missing.joined(separator: ", "))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.vertical, 4)
        }
    }

    private func search() async {
        loading = true
        error = nil
        matches = []
        do {
            let source: any RecipeProvider = provider == "Spoonacular"
                ? SpoonacularProvider(apiKey: RecipeKeyStore.read()) : MealDBProvider()
            let result = try await source.search(ingredients: ingredients)
            guard !Task.isCancelled else { return }
            matches = result
            completedRevision = revision
            loading = false
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error is ProviderError ? error.localizedDescription : "Couldn’t load recipes. Check your connection and try again."
            completedRevision = revision
            loading = false
        }
    }
}

struct RecipeSourceView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("recipeProvider") private var savedProvider = "TheMealDB"
    @State private var selection = "TheMealDB"
    @State private var key = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Recipe source", selection: $selection) {
                    Text("Spoonacular").tag("Spoonacular")
                    Text("TheMealDB").tag("TheMealDB")
                }.pickerStyle(.inline)
                if selection == "Spoonacular" {
                    Section {
                        SecureField("Spoonacular API key", text: $key)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        Link("Get a Spoonacular key", destination: URL(string: "https://spoonacular.com/food-api/console")!)
                    } footer: {
                        Text("Stored securely on this device. Searches use your Spoonacular request allowance.")
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Recipe source").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            if selection == "Spoonacular" { try RecipeKeyStore.save(key.trimmingCharacters(in: .whitespacesAndNewlines)) }
                            savedProvider = selection
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }.disabled(selection == "Spoonacular" && key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { selection = savedProvider; key = RecipeKeyStore.read() }
        }
    }
}

struct SpoonacularDetailView: View {
    let id: String
    @State private var recipe: Recipe?
    @State private var error: String?
    @State private var attempt = UUID()
    var body: some View {
        Group {
            if let recipe { RecipeDetailView(recipe: recipe) }
            else if let error {
                VStack(spacing: 16) {
                    Text(error)
                    Button("Try again") { attempt = UUID() }
                }.padding()
            } else { ProgressView("Loading recipe…") }
        }.task(id: attempt) {
            error = nil
            do { recipe = try await SpoonacularProvider(apiKey: RecipeKeyStore.read()).detail(id: id) }
            catch { self.error = error is ProviderError ? error.localizedDescription : "Couldn’t load this recipe. Please try again." }
        }
    }
}
