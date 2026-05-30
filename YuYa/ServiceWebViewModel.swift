//
//  ServiceWebViewModel.swift
//  YuYa
//
//  Created by Maksim Cherkasov on 30.05.2026.
//

import AppKit
import Combine
import Foundation
import WebKit

@MainActor
protocol ServiceWebViewModelDelegate: AnyObject {
    func serviceWebViewModel(_ model: ServiceWebViewModel, didReceive message: BridgeMessage)
    func serviceWebViewModel(_ model: ServiceWebViewModel, didUpdateURL url: URL)
    func serviceWebViewModel(_ model: ServiceWebViewModel, didFindFaviconURL url: URL)
    func serviceWebViewModel(_ model: ServiceWebViewModel, didUpdateNavigationState navigationState: WebNavigationState)
}

@MainActor
final class ServiceWebViewModel: NSObject, ObservableObject {
    private(set) var service: MusicService
    let webView: WKWebView

    weak var delegate: ServiceWebViewModelDelegate?

    @Published private(set) var navigationState = WebNavigationState()

    private var observations: [NSKeyValueObservation] = []
    private var popupAllowedHosts: Set<String> = []
    private let decoder = JSONDecoder()

    init(service: MusicService, initialURL: URL) {
        self.service = service

        let userContentController = WKUserContentController()
        let bridgeScript = WKUserScript(
            source: BridgeScript.source(for: service),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true,
            in: .page
        )
        userContentController.addUserScript(bridgeScript)
        userContentController.addUserScript(
            WKUserScript(
                source: PopupRoutingScript.source,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false,
                in: .page
            )
        )

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.userContentController = userContentController
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = service.customUserAgent
        self.webView = webView

        super.init()

        userContentController.add(WeakScriptMessageHandler(delegate: self), name: "yuyaBridge")
        userContentController.add(WeakScriptMessageHandler(delegate: self), name: "yuyaPopup")
        webView.navigationDelegate = self
        webView.uiDelegate = self

        observeNavigationState()
        load(url: initialURL)
    }

    func goBack() {
        guard webView.canGoBack else {
            return
        }
        webView.goBack()
    }

    func goForward() {
        guard webView.canGoForward else {
            return
        }
        webView.goForward()
    }

    func reload() {
        webView.reload()
    }

    func update(service: MusicService) {
        let previousURL = self.service.homeURL
        self.service = service
        webView.customUserAgent = service.customUserAgent

        if webView.url == nil || previousURL != service.homeURL && webView.url?.absoluteString == previousURL.absoluteString {
            load(url: service.homeURL)
        }
    }

    func loadHome() {
        load(url: service.homeURL)
    }

    func send(_ command: PlaybackCommand) {
        let script = "window.__yuyaBridge && window.__yuyaBridge.command('\(command.rawValue)')"
        webView.evaluateJavaScript(script) { _, error in
            if let error {
                NSLog("YuYa bridge command failed for \(self.service.id): \(error)")
            }
        }
    }

    func forcePausePlayback() {
        if #available(macOS 12.0, *) {
            webView.pauseAllMediaPlayback { }
        }

        let script = """
        (() => {
          if (window.__yuyaBridge && typeof window.__yuyaBridge.forcePause === "function") {
            return window.__yuyaBridge.forcePause();
          }

          const seenRoots = new Set();
          const mediaElements = [];

          function collect(root) {
            if (!root || seenRoots.has(root)) {
              return;
            }
            seenRoots.add(root);

            try {
              if (!root.querySelectorAll) {
                return;
              }
              root.querySelectorAll("audio, video").forEach(element => mediaElements.push(element));
              root.querySelectorAll("*").forEach(element => {
                if (element.shadowRoot) {
                  collect(element.shadowRoot);
                }
                if (element.tagName === "IFRAME" || element.tagName === "FRAME") {
                  try {
                    collect(element.contentDocument);
                  } catch (_) {}
                }
              });
            } catch (_) {}
          }

          collect(document);
          let pausedAny = false;
          for (const mediaElement of mediaElements) {
            if (mediaElement && mediaElement.pause && !mediaElement.paused) {
              try {
                mediaElement.pause();
                pausedAny = true;
              } catch (_) {}
            }
          }

          if (pausedAny && navigator.mediaSession) {
            try {
              navigator.mediaSession.playbackState = "paused";
            } catch (_) {}
          }

          return pausedAny;
        })();
        """

        webView.evaluateJavaScript(script) { _, error in
            if let error {
                NSLog("YuYa force pause failed for \(self.service.id): \(error)")
            }
        }
    }

    func pauseIfPlaying() {
        forcePausePlayback()
    }

    private func load(url: URL) {
        webView.load(URLRequest(url: url))
    }

    private func observeNavigationState() {
        observations = [
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
                self?.scheduleNavigationStateUpdate(from: webView)
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
                self?.scheduleNavigationStateUpdate(from: webView)
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] webView, _ in
                self?.scheduleNavigationStateUpdate(from: webView)
            }
        ]
    }

    private nonisolated func scheduleNavigationStateUpdate(from webView: WKWebView) {
        Task { @MainActor [weak self, weak webView] in
            guard let webView else {
                return
            }
            self?.updateNavigationState(from: webView)
        }
    }

    private func updateNavigationState(from webView: WKWebView) {
        let updatedState = WebNavigationState(
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward,
            isLoading: webView.isLoading
        )

        guard updatedState != navigationState else {
            return
        }

        navigationState = updatedState
        delegate?.serviceWebViewModel(self, didUpdateNavigationState: updatedState)
    }

    private func handleScriptMessage(_ message: WKScriptMessage) {
        if message.name == "yuyaPopup" {
            handlePopupMessage(message)
            return
        }

        guard message.name == "yuyaBridge" else {
            return
        }

        do {
            let data: Data
            if let body = message.body as? String {
                guard let stringData = body.data(using: .utf8) else {
                    return
                }
                data = stringData
            } else if JSONSerialization.isValidJSONObject(message.body) {
                data = try JSONSerialization.data(withJSONObject: message.body)
            } else {
                return
            }

            let decoded = try decoder.decode(BridgeMessage.self, from: data)
            delegate?.serviceWebViewModel(self, didReceive: decoded)
        } catch {
            NSLog("YuYa failed to decode bridge message for \(service.id): \(error)")
        }
    }

    private func handlePopupMessage(_ message: WKScriptMessage) {
        let urlString: String?
        if let body = message.body as? String {
            urlString = body
        } else if let body = message.body as? [String: Any] {
            urlString = body["url"] as? String
        } else {
            urlString = nil
        }

        guard let urlString,
              let url = URL(string: urlString)
        else {
            return
        }

        routePopupURL(url, in: webView)
    }

    private func updatePersistedURLIfPossible() {
        guard let url = webView.url, service.allows(url) else {
            return
        }
        delegate?.serviceWebViewModel(self, didUpdateURL: url)
    }

    private func updateFaviconURLIfPossible() {
        let script = """
        (() => {
          const links = Array.from(document.querySelectorAll("link[rel]"));
          const icon = links.find(link => {
            const rel = String(link.rel || "").toLowerCase();
            return rel.includes("icon") || rel.includes("apple-touch-icon");
          });
          if (icon && icon.href) {
            return icon.href;
          }
          return window.location.origin + "/favicon.ico";
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, _ in
            guard let self,
                  let value = result as? String,
                  let url = URL(string: value)
            else {
                return
            }

            Task { @MainActor in
                self.delegate?.serviceWebViewModel(self, didFindFaviconURL: url)
            }
        }
    }

    private func routePopupURL(_ url: URL, in webView: WKWebView) {
        guard isWebURL(url) else {
            openExternally(url)
            return
        }

        rememberPopupHost(from: url)
        webView.load(URLRequest(url: url))
    }

    private func routeNewWindowRequest(_ request: URLRequest, in webView: WKWebView) {
        guard let url = request.url else {
            return
        }

        guard isWebURL(url) else {
            openExternally(url)
            return
        }

        rememberPopupHost(from: url)
        webView.load(request)
    }

    private func shouldAllowMainFrameNavigation(to url: URL) -> Bool {
        guard isWebURL(url) else {
            return false
        }

        if service.allows(url) || isPopupAllowed(url) {
            rememberPopupRedirectIfNeeded(to: url)
            return true
        }

        if let currentURL = webView.url,
           isPopupAllowed(currentURL) {
            rememberPopupHost(from: url)
            return true
        }

        return false
    }

    private func rememberPopupRedirectIfNeeded(to url: URL) {
        guard let currentURL = webView.url,
              isPopupAllowed(currentURL),
              !service.allows(url)
        else {
            return
        }

        rememberPopupHost(from: url)
    }

    private func rememberPopupHost(from url: URL) {
        guard let host = url.host(percentEncoded: false)?.lowercased() else {
            return
        }

        popupAllowedHosts.insert(host)
    }

    private func isPopupAllowed(_ url: URL) -> Bool {
        guard let host = url.host(percentEncoded: false)?.lowercased() else {
            return false
        }

        return popupAllowedHosts.contains { allowedHost in
            host == allowedHost || host.hasSuffix(".\(allowedHost)")
        }
    }

    private func isWebURL(_ url: URL) -> Bool {
        url.scheme == "http" || url.scheme == "https"
    }

    private func openExternally(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

extension ServiceWebViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        updatePersistedURLIfPossible()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updatePersistedURLIfPossible()
        updateFaviconURLIfPossible()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if navigationAction.targetFrame == nil {
            routeNewWindowRequest(navigationAction.request, in: webView)
            decisionHandler(.cancel)
            return
        }

        guard navigationAction.targetFrame?.isMainFrame == true else {
            decisionHandler(.allow)
            return
        }

        guard url.scheme == "http" || url.scheme == "https" else {
            openExternally(url)
            decisionHandler(.cancel)
            return
        }

        if shouldAllowMainFrameNavigation(to: url) {
            decisionHandler(.allow)
        } else {
            openExternally(url)
            decisionHandler(.cancel)
        }
    }
}

extension ServiceWebViewModel: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            routeNewWindowRequest(navigationAction.request, in: webView)
        }
        return nil
    }
}

extension ServiceWebViewModel: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        Task { @MainActor in
            self.handleScriptMessage(message)
        }
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

private enum PopupRoutingScript {
    static let source = """
    (() => {
      if (window.__yuyaPopupRoutingInstalled) {
        return;
      }

      Object.defineProperty(window, "__yuyaPopupRoutingInstalled", {
        value: true,
        configurable: false
      });

      const popupHandler = () => {
        try {
          return window.webkit &&
            window.webkit.messageHandlers &&
            window.webkit.messageHandlers.yuyaPopup;
        } catch (_) {
          return null;
        }
      };

      const postPopupURL = (url) => {
        const handler = popupHandler();
        if (!handler || !url || String(url).trim() === "") {
          return false;
        }

        try {
          handler.postMessage({ url: new URL(url, window.location.href).href });
          return true;
        } catch (_) {
          return false;
        }
      };

      const routeInCurrentWindow = (url) => {
        if (postPopupURL(url)) {
          return window;
        }

        if (url && String(url).trim() !== "") {
          try {
            window.location.assign(new URL(url, window.location.href).href);
          } catch (_) {
            window.location.href = url;
          }
        }
        return window;
      };

      window.open = function(url) {
        return routeInCurrentWindow(url);
      };

      document.addEventListener("click", (event) => {
        const target = event.target;
        if (!target || typeof target.closest !== "function") {
          return;
        }

        const anchor = target.closest("a[target]");
        if (!anchor) {
          return;
        }

        const targetName = String(anchor.target || "").toLowerCase();
        if (targetName === "_blank" || targetName === "_new") {
          if (postPopupURL(anchor.href)) {
            event.preventDefault();
            event.stopPropagation();
            return;
          }

          anchor.target = "_self";
        }
      }, true);
    })();
    """
}
