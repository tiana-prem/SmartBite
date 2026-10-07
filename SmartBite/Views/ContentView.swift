//
//  ContentView.swift
//  can_it
//
//  Created by Tiana Prem  on 7/1/26.
//

import SwiftUI
import AVFoundation
import AVKit
import PhotosUI

struct ContentView: View {
    var body: some View {
        TabView{ //nav bar that leads to each page, opens on camera
            CameraView()
                .tabItem{
                    Label("Camera", systemImage: "camera")
                }
            
        }
        
    }
}
#Preview {
    ContentView()
}
