//
//  FaviconLoader.swift
//  YuYa
//
//  Created by Maksim Cherkasov on 30.05.2026.
//

import AppKit
import Foundation

actor FaviconLoader {
    private var cache: [URL: Data] = [:]

    func image(from url: URL) async -> NSImage? {
        do {
            let data: Data
            if let cached = cache[url] {
                data = cached
            } else {
                var request = URLRequest(url: url)
                request.cachePolicy = .returnCacheDataElseLoad
                request.timeoutInterval = 12

                let (loadedData, _) = try await URLSession.shared.data(for: request)
                cache[url] = loadedData
                data = loadedData
            }

            return NSImage(data: data)
        } catch {
            return nil
        }
    }
}
