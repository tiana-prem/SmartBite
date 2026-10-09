//
//  ingredientIdentify.swift
//  SmartBite
//
//  Created by Tiana Prem  on 10/9/26.
//
//

import UIKit
import SwiftUI

struct ingredientIdentify {
    //image must be converted to Base64 which is how the AI understands it, cannot take a raw image
    private func convertImagesToBase64(_ images: [IdentifiableImage]) -> [String] {
        return images.compactMap{identifiableImage in
            guard let imageData = identifiableImage.image.jpegData(compressionQuality: 0.7) else {
                return nil
            }
            return imageData.base64EncodedString()
            
        }
        
    }
        func analyzeObject(images: [IdentifiableImage]) async -> String {//connect to ollama
            let base64Images = convertImagesToBase64(images)
            
            guard !base64Images.isEmpty else { return "Error - No images to analyze" }
            guard let url = URL(string: "http://10.90.252.90:11434/api/chat") else { return "Error" }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type") //data can be sent to outside serve
            
            let payload: [String: Any] = [
                "model": "qwen3-vl:latest",
                "messages": [
                    [
                        "role": "user",
                        "content": "Analyze these images and identify all visible food ingredients. Return only a comma-separated list of ingredient names. Do not include duplicates.",
                        "images": base64Images //this is the dictionary of data which must be sent to the AI - includes the promp and image
                    ]
                ],
                "stream": false
            ]
            
            do{
                let jsonData = try JSONSerialization.data(withJSONObject: payload) //converts data to JSON raw data
                request.httpBody = jsonData
                let(data, _) = try await URLSession.shared.data(for: request) //runs it through the model, waits for the data response back
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = jsonResponse["message"] as? [String:Any],
                   let aiResult = message["content"] as? String{ //converts data to the type we want
                    return aiResult.trimmingCharacters(in: .whitespacesAndNewlines) //makes sure it only returns 1 word so AIView will work correctly
                }
            }catch {
                return "Error: \(error.localizedDescription)" //handles the errors with provided description
            }
            
            return "Unknown"
        }
        
}
