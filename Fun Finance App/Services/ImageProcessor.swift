import UIKit
import CoreImage

protocol ImageProcessing {
    func preprocessImage(_ image: UIImage) async -> ProcessedImageResult
    func createThumbnail(from image: UIImage, maxDimension: CGFloat) -> UIImage?
}

struct ProcessedImageResult {
    let original: UIImage
    let optimized: UIImage
    let thumbnail: UIImage?
}

final class ImageProcessor: ImageProcessing {
    private let maxDimension: CGFloat = 2048
    private let thumbnailDimension: CGFloat = 400

    func preprocessImage(_ image: UIImage) async -> ProcessedImageResult {
        // Run image processing on main actor to avoid Swift 6 concurrency errors
        return await MainActor.run {
            // Create optimized version (resized for faster compression)
            let optimized = self.resize(image: image, maxDimension: self.maxDimension)

            // Create thumbnail for UI preview
            let thumbnail = self.createThumbnail(from: image, maxDimension: self.thumbnailDimension)

            return ProcessedImageResult(
                original: image,
                optimized: optimized,
                thumbnail: thumbnail
            )
        }
    }

    func createThumbnail(from image: UIImage, maxDimension: CGFloat) -> UIImage? {
        return resize(image: image, maxDimension: maxDimension)
    }

    private func resize(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        // If image is already smaller than max dimension, return as-is
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        let newSize: CGSize

        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        // Use high-quality rendering
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resized
    }
}
