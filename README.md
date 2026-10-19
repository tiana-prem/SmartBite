# SmartBite
### Turn food photos into an ingredient list

SmartBite is an iOS prototype that identifies food ingredients from multiple photos. Users capture ingredients, review the images, and send them to a locally hosted vision-language model to produce a single ingredient list.

## What it does
- Captures multiple photos through a custom camera interface.
- Shows a thumbnail of the latest capture and a swipeable photo review screen.
- Sends the captured images together for ingredient identification.
- Requests unique ingredient names in structured JSON.
- Displays the returned ingredients in a SwiftUI list.

## Technical highlights
SmartBite combines native camera capture, image preprocessing, asynchronous networking, and structured AI response parsing. Before inference, images are resized using a 512-point maximum dimension and compressed as JPEGs, then encoded as Base64. The service requests JSON from Qwen through Ollama and extracts the `ingredients` array for display.

**Stack:** Swift, SwiftUI, UIKit, AVFoundation, Ollama, Qwen3-VL (`qwen3-vl:2b-instruct`), `URLSession`, JSONSerialization.

## How it works
1. Capture one or more photos of food ingredients.
2. Open the thumbnail to review the photo collection.
3. Continue to ingredient identification.
4. The app sends the images to Ollama's `/api/chat` endpoint.
5. The response is parsed and shown as an ingredient list.

The prompt asks the model to list each ingredient once and omit non-food objects. These are requested behaviors rather than measured accuracy guarantees.

## Project structure
- `SmartBite/CameraManager.swift` — camera permissions, capture session, and captured images.
- `SmartBite/CameraPreview.swift` — native live camera preview.
- `SmartBite/Views/CameraView.swift` — capture interface.
- `SmartBite/Views/ReviewPhotosView.swift` — paged photo review and analysis navigation.
- `SmartBite/ingredientIdentify.swift` — image processing, AI request, and response parsing.
- `SmartBite/Views/IngredientsView.swift` — ingredient list.
- `SmartBite.xcodeproj` — Xcode project.

## Running the prototype
**Requirements:** a Mac with Xcode supporting the project's iOS 26.5 deployment target, a compatible camera-equipped iOS device, and a reachable computer running Ollama.

1. Clone the repository and open `SmartBite.xcodeproj`.
2. Select your own signing team in Xcode.
3. Install Ollama and download the model:
   ```sh
   ollama pull qwen3-vl:2b-instruct
   ```
4. Run Ollama and make its API reachable from the device.
5. Replace the development server URL in `SmartBite/ingredientIdentify.swift` with `http://<host>:11434/api/chat`. If using the diagnostic helper in `IngredientsView.swift`, update its server URL too.
6. Check local-network permission and development HTTP transport settings for your environment.
7. Build and run on the device, allow camera access, capture photos, and open the review screen.

## Current status
An ingredient-identification prototype. The repository implements photo capture, review, and model-backed ingredient listing. Recipe generation, nutrition analysis, and persistent ingredient storage are not implemented. Model results can vary, and network/error presentation needs further refinement.

## Author
[Tiana Prem](https://github.com/tiana-prem)

