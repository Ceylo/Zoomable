//
//  Zoomable.swift
//  
//
//  Created by Ceylo on 11/12/2021.
//

import UIKit
import SwiftUI

public struct Zoomable<Content: View>: UIViewControllerRepresentable {
    let host: UIHostingController<Content>
    let zoomRange: ClosedRange<CGFloat>
    
    public init(zoomRange: ClosedRange<CGFloat> = 0.1...10,
         @ViewBuilder content: () -> Content) {
        self.zoomRange = zoomRange
        self.host = UIHostingController(rootView: content())
    }
    
    public func makeUIViewController(context: Context) -> ZoomableViewController {
        ZoomableViewController(view: self.host.view,
                               zoomRange: self.zoomRange)
    }
    
    public func updateUIViewController(_ uiViewController: ZoomableViewController, context: Context) {}
}

public class ZoomableViewController : UIViewController, UIScrollViewDelegate {
    let scrollView = UIScrollView()
    let contentView: UIView
    let originalContentSize: CGSize
    
    init(view: UIView,
         zoomRange: ClosedRange<CGFloat>) {
        self.scrollView.minimumZoomScale = zoomRange.lowerBound
        self.scrollView.maximumZoomScale = zoomRange.upperBound
        self.contentView = view
        self.originalContentSize = view.intrinsicContentSize
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(doubleTap(sender:)))
        gestureRecognizer.numberOfTapsRequired = 2
        gestureRecognizer.numberOfTouchesRequired = 1
        
        scrollView.addGestureRecognizer(gestureRecognizer)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.addSubview(contentView)
        self.view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fitContents()
        centerSmallContents()
    }
    
    func centerSmallContents() {
        let contentSize = contentView.frame.size
        let offsetX = max((scrollView.bounds.width - contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - contentSize.height) * 0.5, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: 0, right: 0)
    }
    
    // MARK: UIScrollViewDelegate
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? { contentView }
    public func scrollViewDidZoom(_ scrollView: UIScrollView) { centerSmallContents() }
    
    // MARK: - ZoomToFit
    func zoomToFit(size: CGSize) -> CGFloat {
        let widthRatio = self.scrollView.frame.width / size.width
        let heightRatio = self.scrollView.frame.height / size.height
        return min(widthRatio, heightRatio)
    }
    
    private var fitZoomScale: CGFloat?
    func fitContents() {
        let zoom = zoomToFit(size: originalContentSize)
        
        guard self.fitZoomScale != zoom else { return }
        self.fitZoomScale = zoom
        
        self.scrollView.zoomScale = 1.0
        self.scrollView.contentSize = originalContentSize
        self.scrollView.zoomScale = zoom
    }
    
    @objc func doubleTap(sender: UITapGestureRecognizer) {
        let fitScale = zoomToFit(size: originalContentSize)
        let zoomedScale = max(1, 2 * fitScale)
        let currentScale = scrollView.zoomScale
        let alreadyInFit = abs(currentScale - fitScale) < 1e-3
        
        let newScale = max(scrollView.minimumZoomScale, alreadyInFit ? zoomedScale : fitScale)
        if currentScale != newScale {
            scrollView.setZoomScale(newScale, animated: true)
        }
    }
}

extension CGSize {
    static func * (size: CGSize, scalar: CGFloat) -> CGSize {
        CGSize(width: size.width * scalar, height: size.height * scalar)
    }
}
