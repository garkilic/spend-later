import UIKit

protocol ImageStoring {
    func save(image: UIImage) async throws -> String
    func compressImageToData(_ image: UIImage) async throws -> Data
    func loadImage(named filename: String) -> UIImage?
    func loadImage(from data: Data) -> UIImage?
    func deleteImage(named filename: String)
}

final class ImageStore: ImageStoring {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let targetSizeInBytes = 500_000
    private var imageCache = NSCache<NSString, UIImage>()
    private var compressedDataCache = NSCache<NSString, NSData>()
    private let processingQueue = ImageProcessingQueue.shared

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directoryURL = appSupport.appendingPathComponent("Images", isDirectory: true)
        createDirectoryIfNeeded()

        // Configure image cache - smaller limits for device
        imageCache.countLimit = 20
        imageCache.totalCostLimit = 20 * 1024 * 1024 // 20MB

        // Configure compressed data cache for faster re-saves
        compressedDataCache.countLimit = 10
        compressedDataCache.totalCostLimit = 5 * 1024 * 1024 // 5MB
    }

    func save(image: UIImage) async throws -> String {
        let filename = UUID().uuidString + ".jpg"
        let url = directoryURL.appendingPathComponent(filename)

        // Check if we have cached compressed data for this image
        let cacheKey = "\(image.hash)" as NSString
        let data: Data

        if let cachedData = compressedDataCache.object(forKey: cacheKey) as Data? {
            data = cachedData
        } else {
            // First, preprocess the image (resize if needed) for faster compression
            let processed = await processingQueue.process(image)

            // Use the optimized (resized) image for compression
            data = try await processingQueue.compress(
                image: processed.optimized,
                targetSize: targetSizeInBytes
            )

            // Cache the compressed data
            compressedDataCache.setObject(data as NSData, forKey: cacheKey)
        }

        try data.write(to: url, options: .atomic)
        return filename
    }

    func compressImageToData(_ image: UIImage) async throws -> Data {
        // Check if we have cached compressed data for this image
        let cacheKey = "\(image.hash)" as NSString

        if let cachedData = compressedDataCache.object(forKey: cacheKey) as Data? {
            return cachedData
        }

        // First, preprocess the image (resize if needed) for faster compression
        let processed = await processingQueue.process(image)

        // Use the optimized (resized) image for compression
        let data = try await processingQueue.compress(
            image: processed.optimized,
            targetSize: targetSizeInBytes
        )

        // Cache the compressed data
        compressedDataCache.setObject(data as NSData, forKey: cacheKey)

        return data
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

    func loadImage(from data: Data) -> UIImage? {
        guard !data.isEmpty else { return nil }

        // Check cache using data hash
        let cacheKey = "\(data.hashValue)" as NSString
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }

        // Load from data
        guard let image = UIImage(data: data) else { return nil }

        // Cache for future use
        imageCache.setObject(image, forKey: cacheKey)
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
}
