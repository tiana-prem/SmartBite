//
//  CameraPreview.swift
//  SmartBite
//
//  Created by Tiana Prem  on 10/7/26.
//
import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) ->  UIView { //function called in CameraView to actually show the camera
        let view = UIView(frame: .zero)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context){ //handles resizing ie rotations
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
            
        }
        
        
    }
    func makeCoordinator() -> Coordinator {
        Coordinator() //doesn't need to recreate every time
    }
    class Coordinator{
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

