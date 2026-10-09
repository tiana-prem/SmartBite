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
        if(isLoading){
            Text("Identifying ingredients...")
        } else{
            ForEach(ingredients, id: \.self){ ingredient in
                Text(ingredient)
            }
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
        }
        isLoading = false
        
    }
}
