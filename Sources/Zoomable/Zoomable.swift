//
//  Zoomable.swift
//
//
//  Created by Ceylo on 11/12/2021.
//

import SwiftUI
import UIKit

public enum ZoomLevel: Sendable {
    case fit
    case fill
    /// minimum between `fill` and `scaledFit(scale: maxScaledFit)`.
    case boundedFill(maxScaledFit: Float)
    /// `scale` x `fit`.
    case scaledFit(scale: Float)
}

/// Displays any SwiftUI content in a zoomable, scrollable container.
///
/// The content must have an intrinsic size (e.g. a non-resizable `Image`).
/// Double tap toggles between the primary and secondary zoom levels, zooming
/// towards the tapped point. Rotating the device resets the zoom.
public struct Zoomable<Content: View>: UIViewControllerRepresentable {
    private let content: Content
    private var initialZoomLevel: ZoomLevel = .fit
    private var primaryZoomLevel: ZoomLevel = .fit
    private var secondaryZoomLevel: ZoomLevel = .scaledFit(scale: 2)
    private var maximumZoomScale: CGFloat = 10
    private var isZoomed: Binding<Bool>?

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public func initialZoomLevel(_ zoomLevel: ZoomLevel) -> Self {
        var copy = self
        copy.initialZoomLevel = zoomLevel
        return copy
    }

    public func primaryZoomLevel(_ zoomLevel: ZoomLevel) -> Self {
        var copy = self
        copy.primaryZoomLevel = zoomLevel
        return copy
    }

    public func secondaryZoomLevel(_ zoomLevel: ZoomLevel) -> Self {
        var copy = self
        copy.secondaryZoomLevel = zoomLevel
        return copy
    }

    /// The maximum scale of the content, relative to its original size. Defaults to 10.
    public func maximumZoomScale(_ scale: CGFloat) -> Self {
        var copy = self
        copy.maximumZoomScale = scale
        return copy
    }

    /// Reports whether the content is currently zoomed in beyond the primary zoom level.
    public func isZoomed(_ binding: Binding<Bool>) -> Self {
        var copy = self
        copy.isZoomed = binding
        return copy
    }

    public func makeUIViewController(context: Context) -> ZoomableViewController<Content> {
        ZoomableViewController(
            rootView: content,
            initialZoomLevel: initialZoomLevel,
            primaryZoomLevel: primaryZoomLevel,
            secondaryZoomLevel: secondaryZoomLevel
        )
    }

    public func updateUIViewController(_ viewController: ZoomableViewController<Content>, context: Context) {
        let scrollView = viewController.scrollView
        let environment = context.environment

        viewController.hostingController.rootView = content
        // Assigning the same value is not free: lowering the maximum below the current
        // zoom scale makes UIKit clamp it and call back synchronously.
        if scrollView.maximumZoomScale != maximumZoomScale {
            scrollView.maximumZoomScale = maximumZoomScale
        }
        // Driven by the standard `.scrollIndicators(_:axes:)` and `.disabled(_:)` modifiers.
        scrollView.showsHorizontalScrollIndicator = environment.horizontalScrollIndicatorVisibility.isShown
        scrollView.showsVerticalScrollIndicator = environment.verticalScrollIndicatorVisibility.isShown
        viewController.isInteractionEnabled = environment.isEnabled
        viewController.onZoomedChange = { [isZoomed] zoomed in
            // Deferred because UIKit can report zoom changes while SwiftUI is still
            // updating, and writing state during a view update is not allowed.
            Task { @MainActor in
                if isZoomed?.wrappedValue != zoomed {
                    isZoomed?.wrappedValue = zoomed
                }
            }
        }
    }
}

private extension ScrollIndicatorVisibility {
    var isShown: Bool { self != .hidden && self != .never }
}

public final class ZoomableViewController<Content: View>: UIViewController, UIScrollViewDelegate {
    let scrollView = UIScrollView()
    let hostingController: UIHostingController<Content>
    private var contentView: UIView { hostingController.view }
    private let originalContentSize: CGSize
    private let initialZoomLevel: ZoomLevel
    private let primaryZoomLevel: ZoomLevel
    private let secondaryZoomLevel: ZoomLevel
    private var lastBoundsSize: CGSize = .zero
    private var lastReportedZoomed: Bool?
    private let doubleTapRecognizer = UITapGestureRecognizer()

    var onZoomedChange: ((Bool) -> Void)?

    var isInteractionEnabled = true {
        didSet { applyInteractionState() }
    }

    init(
        rootView: Content,
        initialZoomLevel: ZoomLevel,
        primaryZoomLevel: ZoomLevel,
        secondaryZoomLevel: ZoomLevel
    ) {
        let host = UIHostingController(rootView: rootView)
        host.sizingOptions = .intrinsicContentSize
        self.hostingController = host
        self.originalContentSize = host.view.intrinsicContentSize
        self.initialZoomLevel = initialZoomLevel
        self.primaryZoomLevel = primaryZoomLevel
        self.secondaryZoomLevel = secondaryZoomLevel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self

        doubleTapRecognizer.addTarget(self, action: #selector(doubleTap))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.numberOfTouchesRequired = 1
        scrollView.addGestureRecognizer(doubleTapRecognizer)

        addChild(hostingController)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        view.addSubview(scrollView)
        hostingController.didMove(toParent: self)
        applyInteractionState()

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func applyInteractionState() {
        scrollView.isScrollEnabled = isInteractionEnabled
        scrollView.pinchGestureRecognizer?.isEnabled = isInteractionEnabled
        doubleTapRecognizer.isEnabled = isInteractionEnabled
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The first layout and any later size change (e.g. rotation) restart from
        // the initial zoom level, since the previous zoom/offset no longer makes sense.
        if scrollView.bounds.size != lastBoundsSize, scrollView.bounds.size != .zero {
            lastBoundsSize = scrollView.bounds.size
            resetZoom()
        }
        centerSmallContents()
    }

    private func resetZoom() {
        guard originalContentSize.width > 0, originalContentSize.height > 0 else { return }
        scrollView.minimumZoomScale = fitScale
        // UIKit creates the pinch recognizer lazily once the zoom range is non-empty.
        applyInteractionState()
        scrollView.zoomScale = 1
        scrollView.contentSize = originalContentSize
        scrollView.zoomScale = max(scrollView.minimumZoomScale, initialScale)
        centerSmallContents()
        scrollView.contentOffset = CGPoint(
            x: -scrollView.contentInset.left,
            y: -scrollView.contentInset.top
        )
        notifyZoomChange()
    }

    private func centerSmallContents() {
        let contentSize = contentView.frame.size
        let offsetX = max((scrollView.bounds.width - contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - contentSize.height) * 0.5, 0)
        let inset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
        if scrollView.contentInset != inset {
            scrollView.contentInset = inset
        }
    }

    private func notifyZoomChange() {
        // scrollViewDidZoom fires every frame of a pinch; only report actual changes.
        let zoomed = scrollView.zoomScale > primaryScale + 1e-3
        guard zoomed != lastReportedZoomed else { return }
        lastReportedZoomed = zoomed
        onZoomedChange?(zoomed)
    }

    // MARK: UIScrollViewDelegate
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? { contentView }

    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerSmallContents()
        notifyZoomChange()
    }

    // MARK: - Zoom levels
    private var fitScale: CGFloat {
        min(scrollView.bounds.width / originalContentSize.width, scrollView.bounds.height / originalContentSize.height)
    }

    private var fillScale: CGFloat {
        max(scrollView.bounds.width / originalContentSize.width, scrollView.bounds.height / originalContentSize.height)
    }

    private func scale(for zoomLevel: ZoomLevel) -> CGFloat {
        switch zoomLevel {
        case .fit:
            fitScale
        case .fill:
            fillScale
        case let .boundedFill(maxScaledFit):
            min(CGFloat(maxScaledFit) * fitScale, fillScale)
        case let .scaledFit(scale):
            CGFloat(scale) * fitScale
        }
    }

    private var initialScale: CGFloat { scale(for: initialZoomLevel) }
    private var primaryScale: CGFloat { scale(for: primaryZoomLevel) }
    private var secondaryScale: CGFloat { scale(for: secondaryZoomLevel) }

    @objc private func doubleTap(_ recognizer: UITapGestureRecognizer) {
        let currentScale = scrollView.zoomScale
        let inPrimaryScale = abs(currentScale - primaryScale) < 1e-3
        let newScale = min(
            max(scrollView.minimumZoomScale, inPrimaryScale ? secondaryScale : primaryScale),
            scrollView.maximumZoomScale
        )
        guard abs(currentScale - newScale) > 1e-3 else { return }

        // Zoom towards the tapped point: show a rect centered on it that, at
        // `newScale`, exactly fills the scroll view.
        let tapPoint = recognizer.location(in: contentView)
        let visibleSize = CGSize(
            width: scrollView.bounds.width / newScale,
            height: scrollView.bounds.height / newScale
        )
        let rect = CGRect(
            x: tapPoint.x - visibleSize.width / 2,
            y: tapPoint.y - visibleSize.height / 2,
            width: visibleSize.width,
            height: visibleSize.height
        )
        scrollView.zoom(to: rect, animated: true)
    }
}
