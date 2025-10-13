import UIKit

/// Manages a dedicated queue for image processing operations
/// This ensures image operations don't block the main thread or UI interactions
final class ImageProcessingQueue {
    static let shared = ImageProcessingQueue()

    private let queue: DispatchQueue
    private let imageProcessor: ImageProcessing

    private init(imageProcessor: ImageProcessing = ImageProcessor()) {
        // Create a concurrent queue with utility QoS (lower priority than user-initiated)
        // This ensures UI interactions remain responsive
        self.queue = DispatchQueue(
            label: "com.funfinance.imageprocessing",
            qos: .utility,
            attributes: .concurrent
        )
        self.imageProcessor = imageProcessor
    }

    /// Process an image asynchronously and return the result
    func process(_ image: UIImage) async -> ProcessedImageResult {
        return await withCheckedContinuation { continuation in
            queue.async {
                Task {
                    let result = await self.imageProcessor.preprocessImage(image)
                    continuation.resume(returning: result)
                }
            }
        }
    }

    /// Create a thumbnail asynchronously
    func createThumbnail(from image: UIImage, maxDimension: CGFloat = 400) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            queue.async {
                let thumbnail = self.imageProcessor.createThumbnail(from: image, maxDimension: maxDimension)
                continuation.resume(returning: thumbnail)
            }
        }
    }

    /// Compress image data asynchronously with optimized settings
    func compress(image: UIImage, targetSize: Int = 500_000) async throws -> Data {
        return try await Task.detached(priority: .utility) {
            // Start with lower quality for faster initial compression
            var quality: CGFloat = 0.6
            guard var data = image.jpegData(compressionQuality: quality) else {
                throw ImageProcessingError.compressionFailed
            }

            // Iteratively reduce quality if needed (max 3 iterations for speed)
            var iterations = 0
            while data.count > targetSize && quality > 0.3 && iterations < 3 {
                quality -= 0.15
                if let newData = image.jpegData(compressionQuality: quality) {
                    data = newData
                }
                iterations += 1
            }

            return data
        }.value
    }
}

enum ImageProcessingError: Error, LocalizedError {
    case compressionFailed
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .processingFailed:
            return "Failed to process image"
        }
    }
}
