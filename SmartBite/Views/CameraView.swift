//
//  CameraView.swift
//  SmartBite
//
//  Created by Tiana Prem  on 10/7/26.
//
import AVFoundation
import SwiftUI
import AVKit
import PhotosUI

struct CameraView: View{
    @StateObject private var cameraManager = CameraManager()
    @State private var showingReview = false
    @State private var selectedPhotoIndex = 0 //starts at 0, counts as more photos are taken
    //@State private var showingCamera = false
    var body: some View{
        ZStack{
            VStack{
                ZStack{
                    
                    if cameraManager.authorizationStatus ==
                        .authorized{
                        VStack{
                            CameraPreview(session: cameraManager.session)
                                .frame(width: 350, height: 550)
                                .cornerRadius(12)
                                .clipped()
                                .padding(.top, 15)
                                .padding(.bottom, 15)
                            ZStack{
                                Spacer()
                                Button{ //click photo button by calling function
                                    cameraManager.capturePhoto()
                                } label: {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 3)
                                        .frame(width: 70, height:70)
                                        .overlay {
                                            Circle()
                                                .fill(.white)
                                                .frame(width:60, height: 60)
                                        }
                                    
                                }
                                
                                if let latest = cameraManager.capturedImages.last{
                                    HStack{
                                        Spacer()
                                        Button {
                                            selectedPhotoIndex = 0//cameraManager.capturedImages.count - 1
                                            showingReview = true
                                        } label: {
                                            Image(uiImage: latest.image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 60, height: 60)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .overlay{
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(.white, lineWidth: 2)
                                                }
                                                .clipped()
                                        }
                                    }
                                    } else {
                                        Color.clear
                                            .frame(width: 60, height: 60)
                                    }
                                }

                        }
                    } else { //must have authroization, else leads to setting from this screen
                        VStack{
                            Spacer()
                            Image(systemName: "camera.fill")
                                .font(.largeTitle)
                                .foregroundStyle(Color.gray)
                            Text("Camera Access Required")
                                .foregroundStyle(.white)
                            if cameraManager.authorizationStatus == .denied{
                                Text("Please enable camera in settings")
                                    .foregroundStyle(.white)
                                Button("Open Settings"){
                                    if let settingsURL = URL(string: UIApplication.openSettingsURLString){
                                        UIApplication.shared.open(settingsURL) //leads to settings app
                                    }
                                }
                            }
                            Spacer()
                        }
                    }
                }
                
                Spacer()
                
                
            }
            //                .sheet(item: $cameraManager.capturedImage){ //clears image value when app opens and the preview screen is swiped down
            //                    item in
            //                    PhotoPreviewView(item: item, onDismiss: {
            //                        cameraManager.capturedImage = nil
            //                    })
            //
            //                }
            .onAppear{
                cameraManager.checkAuthorization()
                //cameraManager.capturedImage = nil
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showingReview){
            ReviewPhotosView(images: cameraManager.capturedImages, selectedIndex: $selectedPhotoIndex, isPresented: $showingReview)
        }
        
    }
    
}
