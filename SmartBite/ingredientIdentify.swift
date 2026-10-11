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
    
    func resizeImage(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 512

        // Find the scale factor for the image
        let scale = min(
            maxDimension / image.size.width,
            maxDimension / image.size.height,
            1.0
        )

        // Calculate new dimensions
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        // Create the resized image
        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    //image must be converted to Base64 which is how the AI understands it, cannot take a raw image
   
    private func convertImagesToBase64(_ images: [IdentifiableImage]) -> [String] {
        return images.compactMap { identifiableImage in

            // Step 1: Resize the original image
            let smallerImage = resizeImage(identifiableImage.image)
            print("Original image: \(identifiableImage.image.size)")
            print("Resized image: \(smallerImage.size)")
            print("Actual pixel dimensions: \(smallerImage.cgImage?.width ?? 0) x \(smallerImage.cgImage?.height ?? 0)")

            // Step 2: Convert resized image to JPEG data
            guard let imageData = smallerImage.jpegData(compressionQuality: 0.7) else {
                return nil
            }

            // Step 3: Convert JPEG data into Base64
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
                "model": "qwen3-vl:2b-instruct",
                //"think" : false,
                "messages": [
                    [
                        "role": "user",
                        "content": """
                            Identify the unique food ingredients visible in these images.

                            Rules:
                            - Return each distinct ingredient exactly ONCE.
                            - If multiple images contain the same ingredient, list it only once.
                            - Use simple ingredient names, such as "apple" or "tomato".
                            - Do not list non-food objects.
                            - Do not include explanations.

                            Return JSON in this exact format:
                            {"ingredients": ["apple", "banana"]} 
                        """,
                        "images": base64Images //this is the dictionary of data which must be sent to the AI - includes the promp and image
                    ]
                ],
                "stream": false,
                "format" : "json",
                "options": ["temperature" : 0, "num_predict": 150, "num_ctx": 9500],
                "keep_alive": "30s"
            ]
            
            do{
                let jsonData = try JSONSerialization.data(withJSONObject: payload) //converts data to JSON raw data
                request.httpBody = jsonData
                print("Sending images to Qwen...")

                let(data, response) = try await URLSession.shared.data(for: request) //runs it through the model, waits for the data response back
                
                print("Qwen responded!")
                

                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status: \(httpResponse.statusCode)")
                }

                print("RAW AI RESPONSE:")
                print(String(data: data, encoding: .utf8) ?? "Could not decode response")
                
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = jsonResponse["message"] as? [String:Any],
                   let aiResult = message["content"] as? String{
                    let cleanedResult = aiResult.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let ingredientData = cleanedResult.data(using: .utf8),
                       let parsedJSON = try? JSONSerialization.jsonObject(with: ingredientData) as? [String: Any],
                       let ingredients = parsedJSON["ingredients"] as? [String]{
                        print("Extracted ingredients: \(ingredients)")
                        return ingredients.joined(separator: ", ")
                    }//converts data to the type we want
                     //makes sure it only returns 1 word so AIView will work correctly
                }
            }catch {
                return "Error: \(error.localizedDescription)" //handles the errors with provided description
            }
            
            return "Unknown"
        }
        
}
