//
//  IngredientsView.swift
//  SmartBite
//
//  Created by Tiana Prem  on 10/9/26.
//
import SwiftUI
struct IngredientsView: View{
    let images: [IdentifiableImage]
    @State private var ingredients: [String] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View{
        VStack{
            if(isLoading){
                Text("Identifying ingredients...")
            } else{
                VStack{
                    Text("Available Ingredients")
                        .font(.title)
                List(ingredients, id: \.self) { ingredient in
                        HStack {
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            
                            Text(ingredient)
                        }
                    }
                }
            }
            
        }
        .task {
            await loadIngredients()
        }
    }
    
    private func loadIngredients() async{
        isLoading = true
        let result = await ingredientIdentify().analyzeObject(images: images)
        
        if result == "Unkonwn" {
            errorMessage = result
        } else{
            ingredients = result
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            print(result)
        }
        isLoading = false
        
    }
    private func testConnection() async {
        print("Testing Ollama connection...")

        guard let url = URL(
            string: "http://10.90.252.90:11434/api/tags"
        ) else {
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status:", httpResponse.statusCode)
            }

            print(String(data: data, encoding: .utf8) ?? "No data")

        } catch {
            print("Connection failed:", error.localizedDescription)
            print("Error details:", error)
        }
    }
}
