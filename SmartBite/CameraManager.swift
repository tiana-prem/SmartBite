//
//  CameraManager.swift
//  SmartBite
//
//  Created by Tiana Prem  on 10/7/26.
//
import AVFoundation
import SwiftUI
import Combine

class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var capturedImages: [IdentifiableImage] = [] //optional - takes nil
    @Published var isSessionRunning = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined //must check
    
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    
    private let sessionQueue = DispatchQueue(label: "com.customcamera.sessionQueue")
    
    override init(){
        super.init()
    }
    
    func checkAuthorization(){
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationStatus = .authorized
            setupSession() //starts camera
        case.notDetermined:
            authorizationStatus = .notDetermined
            AVCaptureDevice.requestAccess(for: .video) {[weak self] granted in
                DispatchQueue.main.async { //asks for authroization status
                    self?.authorizationStatus = granted ? .authorized : .denied
                    if granted {
                        self?.setupSession()
                    }
                }
            }
        case .denied, .restricted:
            authorizationStatus = .denied
            
        @unknown default:
            authorizationStatus = .denied
        }
    }
    
    private func setupSession(){ //builds the camera
        sessionQueue.async {
            [weak self] in
            guard let self = self else{return}
            
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            
            //camera input from device
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), let input = try? AVCaptureDeviceInput(device: camera) else {
                print("failed to access camera")
                self.session.commitConfiguration()
                return
            }
            if self.session.canAddInput(input){
                self.session.addInput(input)
                self.currentInput = input
            }
            
            //add photo layer
            if self.session.canAddOutput(self.photoOutput){
                self.session.addOutput(self.photoOutput)
                
                self.photoOutput.isHighResolutionCaptureEnabled = true
                self.photoOutput.maxPhotoQualityPrioritization = .quality
            }
            self.session.commitConfiguration()
            //start the session
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
            }
        }
    }
    
    func capturePhoto(){ //called later in the camera view
        sessionQueue.async{
            [weak self] in
            guard let self = self else { return }
            
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .auto //depends on the lighting
            if self.photoOutput.isHighResolutionCaptureEnabled {
                settings.isHighResolutionPhotoEnabled = true //default
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error{
            print("Photo capture error: \(error.localizedDescription)")
            return //handles errors
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let uiImage = UIImage(data: imageData) else{
            print("Failed to convert photo to image")
            return //must be in form UIImage
        }
        
        DispatchQueue.main.async { //must occur on main thread
            [weak self] in
            self?.capturedImages.append(IdentifiableImage(image: uiImage))
        }
    }
}

struct IdentifiableImage: Identifiable{ //must be identifiable - error fix
    let id  = UUID()
    let image: UIImage
}
