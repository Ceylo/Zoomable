//
//  ContentView.swift
//  DemoApp
//
//  Created by Ceylo on 11/12/2021.
//

import SwiftUI
import Zoomable

struct ContentView: View {
    var body: some View {
        Zoomable(allowZoomOutBeyondFit: false) {
            Image("bird_wildlife_sky_clouds")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
