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

## Options
```swift
Zoomable { Image(uiImage: image) }
    .secondaryZoomLevel(.scaledFit(scale: 2.5)) // double tap target, zooms towards the tapped point
    .maximumZoomScale(10)
    .isZoomed($isZoomed)                         // observe whether the content is zoomed in
    .scrollIndicators(.hidden)                   // standard SwiftUI modifier
    .disabled(isTransitioning)                   // standard SwiftUI modifier, turns off all interaction
```
Double tap toggles between the primary and secondary zoom levels. Rotating the device resets the zoom.

`Zoomable`'s own modifiers (`initialZoomLevel`, `primaryZoomLevel`, `secondaryZoomLevel`, `maximumZoomScale`, `isZoomed`) return `Zoomable`, so apply them before any standard SwiftUI modifier such as `.padding()` or `.disabled(_:)`.

## Showing different content in the same view
`Zoomable` measures its content once, when it is created. If you reuse one `Zoomable` to show different images (for example the detail pane of a split view driven by a list selection), attach `.id(_:)` with a value that is unique per image. SwiftUI then creates a fresh `Zoomable` for each one, so the zoom limits and zoom level start over. Without it, a new image keeps the previous image's size and zoom.

```swift
NavigationSplitView {
    List(items, selection: $selection) { item in
        Text(item.name).tag(item.id)
    }
} detail: {
    if let item = items.first(where: { $0.id == selection }) {
        Zoomable {
            Image(item.imageName)
        }
        .id(item.id) // required when the image can change
    }
}
```
