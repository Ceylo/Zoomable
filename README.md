# Zoomable

A SwiftUI wrapper over UIScrollView that allows displaying any content and zooming in and out of it through pinch gesture. Double tap toggles between fit and zoomed in. Once zoomed in, the content can be scrolled.

Getting a zoomable image becomes as simple as
```swift
import SwiftUI
import Zoomable

struct ContentView: View {
    var body: some View {
        Zoomable {
            Image("bird_wildlife_sky_clouds")
        }
    }
}
```
