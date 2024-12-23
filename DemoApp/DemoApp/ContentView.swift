//
//  ContentView.swift
//  DemoApp
//
//  Created by Ceylo on 11/12/2021.
//

import SwiftUI
import Zoomable

struct ContentView: View {
    @State private var showSheet = false
    
    var body: some View {
        ScrollView {
            Image("bird_wildlife_sky_clouds")
                .resizable()
                .scaledToFit()
                .onTapGesture {
                    showSheet = true
                }
                .sheet(isPresented: $showSheet) {
                    Zoomable {
                        Image("bird_wildlife_sky_clouds")
                            .resizable()
                            .frame(maxWidth: 400, maxHeight: 400)
                        
                    }
                    .initialZoomLevel(.fit)
                    .secondaryZoomLevel(.fill)
                    .ignoresSafeArea()
                }
                
        }
    }
}

#Preview {
    ContentView()
}
