import Foundation
import UIKit

/// In-memory avatar cache + in-flight deduplication so the same profile URL is only fetched once.
enum AvatarImageLoader {
    private static let memory: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 250
        c.totalCostLimit = 64 * 1024 * 1024
        return c
    }()
    private static let inflightLock = NSLock()
    private static var inflight: [String: Task<UIImage?, Never>] = [:]

    static func cachedImage(for url: URL) -> UIImage? {
        memory.object(forKey: url.absoluteString as NSString)
    }

    static func load(url: URL) async -> UIImage? {
        let key = url.absoluteString
        if let hit = memory.object(forKey: key as NSString) {
            return hit
        }

        inflightLock.lock()
        if let existing = inflight[key] {
            inflightLock.unlock()
            return await existing.value
        }
        let task = Task<UIImage?, Never> {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return nil }
                memory.setObject(image, forKey: key as NSString, cost: data.count)
                return image
            } catch {
                return nil
            }
        }
        inflight[key] = task
        inflightLock.unlock()

        let result = await task.value
        inflightLock.lock()
        inflight[key] = nil
        inflightLock.unlock()
        return result
    }
}
