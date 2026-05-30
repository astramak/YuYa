//
//  WebViewStack.swift
//  YuYa
//
//  Created by Maksim Cherkasov on 30.05.2026.
//

import AppKit
import SwiftUI
import WebKit

struct WebViewStack: NSViewRepresentable {
    @ObservedObject var appModel: AppModel

    func makeNSView(context: Context) -> WebViewHostView {
        let hostView = WebViewHostView()

        installWebViews(in: hostView)
        return hostView
    }

    func updateNSView(_ nsView: WebViewHostView, context: Context) {
        installWebViews(in: nsView)
    }

    private func installWebViews(in hostView: WebViewHostView) {
        hostView.topContentInset = TopChromeMetrics.webContentTopInset
        hostView.topHitTestExclusion = TopChromeMetrics.webContentTopHitTestExclusion

        let serviceIDs = Set(appModel.services.map(\.id))
        hostView.removeMissingWebViews(keeping: serviceIDs)

        for service in appModel.services {
            hostView.install(appModel.webViewModel(for: service).webView, for: service.id)
        }

        hostView.select(appModel.selectedServiceID)
    }
}

final class WebViewHostView: NSView {
    private var webViews: [String: WKWebView] = [:]
    private var topConstraints: [String: NSLayoutConstraint] = [:]
    private var selectedServiceID: String?
    var topContentInset: CGFloat = 0 {
        didSet {
            updateTopConstraintConstants()
        }
    }
    var topHitTestExclusion: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let topBandStart = bounds.maxY - topHitTestExclusion
        if point.y >= topBandStart {
            return nil
        }

        return super.hitTest(point)
    }

    func install(_ webView: WKWebView, for serviceID: String) {
        guard webViews[serviceID] == nil else {
            return
        }

        webView.translatesAutoresizingMaskIntoConstraints = false
        webViews[serviceID] = webView
        addSubview(webView)

        let topConstraint = webView.topAnchor.constraint(equalTo: topAnchor, constant: topContentInset)
        topConstraints[serviceID] = topConstraint

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            topConstraint,
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func select(_ serviceID: String) {
        selectedServiceID = serviceID

        for (candidate, webView) in webViews {
            let isSelected = candidate == serviceID
            webView.isHidden = !isSelected
            if isSelected {
                webView.window?.makeFirstResponder(webView)
            }
        }
    }

    func removeMissingWebViews(keeping serviceIDs: Set<String>) {
        for (serviceID, webView) in webViews where !serviceIDs.contains(serviceID) {
            webView.removeFromSuperview()
            webViews[serviceID] = nil
            topConstraints[serviceID] = nil
        }
    }

    private func updateTopConstraintConstants() {
        for constraint in topConstraints.values {
            constraint.constant = topContentInset
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    let onWindowAvailable: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onWindowAvailable(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onWindowAvailable(window)
            }
        }
    }
}
