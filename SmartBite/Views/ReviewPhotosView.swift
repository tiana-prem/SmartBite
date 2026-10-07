//
//  ReviewPhotosView.swift
//  SmartBite
//
//  Created by Tiana Prem  on 10/7/26.
//

import SwiftUI
struct ReviewPhotosView: View{
    let images: [IdentifiableImage]
    
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack{
                HStack{
                    Button{
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.white)
                            .font(.title2)
                    }
                    Spacer()
                    Text("\(selectedIndex+1) / \(images.count)")
                        .foregroundStyle(Color.white)
                    Spacer()
                    Image(systemName: "xmark")
                        .font(.title2)
                        .opacity(0)
                }
                .padding()
                
                TabView(selection: $selectedIndex){
                    ForEach(
                        Array(images.enumerated()),
                        id: \.element.id
                    ) { index, item in
                        Image(uiImage: item.image)
                            .resizable()
                            .scaledToFit()
                            .tag(index)
                    }
                    
                }
                .tabViewStyle(
                    .page(indexDisplayMode: .automatic)
                )
            }
        }
    }
}
