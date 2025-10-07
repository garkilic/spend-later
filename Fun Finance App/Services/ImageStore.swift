import UIKit

protocol ImageStoring {
    func save(image: UIImage) throws -> String
    func loadImage(named filename: String) -> UIImage?
    func deleteImage(named filename: String)
}

final class ImageStore: ImageStoring {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let targetSizeInBytes = 500_000
    private var imageCache = NSCache<NSString, UIImage>()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directoryURL = appSupport.appendingPathComponent("Images", isDirectory: true)
        createDirectoryIfNeeded()

        // Configure cache - smaller limits for device
        imageCache.countLimit = 20 // Reduced from 50
        imageCache.totalCostLimit = 20 * 1024 * 1024 // 20MB instead of 50MB
    }

    func save(image: UIImage) throws -> String {
        let filename = UUID().uuidString + ".jpg"
        let url = directoryURL.appendingPathComponent(filename)
        let data = try compress(image: image)
        try data.write(to: url, options: .atomic)
        return filename
    }

    func loadImage(named filename: String) -> UIImage? {
        guard !filename.isEmpty else { return nil }

        // Check cache first
        let key = filename as NSString
        if let cachedImage = imageCache.object(forKey: key) {
            return cachedImage
        }

        // Load from disk
        let url = directoryURL.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }

        // Cache for future use
        imageCache.setObject(image, forKey: key)
        return image
    }

    func deleteImage(named filename: String) {
        guard !filename.isEmpty else { return }

        // Remove from cache
        let key = filename as NSString
        imageCache.removeObject(forKey: key)

        // Remove from disk
        let url = directoryURL.appendingPathComponent(filename)
        try? fileManager.removeItem(at: url)
    }
}

private extension ImageStore {
    func createDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: directoryURL.path) else { return }
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func compress(image: UIImage) throws -> Data {
        var quality: CGFloat = 0.7
        guard var data = image.jpegData(compressionQuality: quality) else {
            throw NSError(domain: "ImageStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create JPEG data"])
        }

        while data.count > targetSizeInBytes && quality > 0.3 {
            quality -= 0.1
            if let newData = image.jpegData(compressionQuality: quality) {
                data = newData
            } else {
                break
            }
        }
        return data
    }
}
