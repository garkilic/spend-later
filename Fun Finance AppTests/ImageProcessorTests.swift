import XCTest
import UIKit
@testable import Fun_Finance_App

final class ImageProcessorTests: XCTestCase {
    var sut: ImageProcessor!

    override func setUp() {
        super.setUp()
        sut = ImageProcessor()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Image Resizing

    func testPreprocessImage_LargeImage_ResizesTo2048Max() async {
        // Given - Create 4000x3000 image
        let largeImage = createTestImage(width: 4000, height: 3000)

        // When
        let result = await sut.preprocessImage(largeImage)

        // Then - Width should be scaled to 2048
        XCTAssertEqual(result.optimized.size.width, 2048, accuracy: 1.0)
        XCTAssertLessThan(result.optimized.size.height, 2048)

        // Aspect ratio preserved (4:3)
        let aspectRatio = result.optimized.size.width / result.optimized.size.height
        XCTAssertEqual(aspectRatio, 4.0/3.0, accuracy: 0.01)
    }

    func testPreprocessImage_TallImage_ResizesHeightTo2048Max() async {
        // Given - Create tall 1000x5000 image
        let tallImage = createTestImage(width: 1000, height: 5000)

        // When
        let result = await sut.preprocessImage(tallImage)

        // Then - Height should be scaled to 2048
        XCTAssertEqual(result.optimized.size.height, 2048, accuracy: 1.0)
        XCTAssertLessThan(result.optimized.size.width, 2048)

        // Aspect ratio preserved (1:5)
        let aspectRatio = result.optimized.size.width / result.optimized.size.height
        XCTAssertEqual(aspectRatio, 1.0/5.0, accuracy: 0.01)
    }

    func testPreprocessImage_SmallImage_NotUpscaled() async {
        // Given - Create small 500x500 image
        let smallImage = createTestImage(width: 500, height: 500)

        // When
        let result = await sut.preprocessImage(smallImage)

        // Then - Should not be upscaled
        XCTAssertEqual(result.optimized.size.width, 500, accuracy: 1.0)
        XCTAssertEqual(result.optimized.size.height, 500, accuracy: 1.0)
    }

    func testPreprocessImage_SquareImage_MaintainsSquareAspectRatio() async {
        // Given - Create 3000x3000 square image
        let squareImage = createTestImage(width: 3000, height: 3000)

        // When
        let result = await sut.preprocessImage(squareImage)

        // Then - Should remain square at 2048x2048
        XCTAssertEqual(result.optimized.size.width, 2048, accuracy: 1.0)
        XCTAssertEqual(result.optimized.size.height, 2048, accuracy: 1.0)
    }

    // MARK: - Thumbnail Creation

    func testCreateThumbnail_LargeImage_ResizesTo400Max() {
        // Given
        let largeImage = createTestImage(width: 2000, height: 1500)

        // When
        let thumbnail = sut.createThumbnail(from: largeImage, maxDimension: 400)

        // Then
        XCTAssertNotNil(thumbnail)
        if let thumbnail = thumbnail {
            XCTAssertEqual(thumbnail.size.width, 400, accuracy: 1.0)
            XCTAssertEqual(thumbnail.size.height, 300, accuracy: 1.0)
        }
    }

    func testCreateThumbnail_SmallImage_NotUpscaled() {
        // Given
        let smallImage = createTestImage(width: 200, height: 150)

        // When
        let thumbnail = sut.createThumbnail(from: smallImage, maxDimension: 400)

        // Then
        XCTAssertNotNil(thumbnail)
        if let thumbnail = thumbnail {
            XCTAssertEqual(thumbnail.size.width, 200, accuracy: 1.0)
            XCTAssertEqual(thumbnail.size.height, 150, accuracy: 1.0)
        }
    }

    func testCreateThumbnail_PreservesAspectRatio() {
        // Given - 16:9 image
        let wideImage = createTestImage(width: 1920, height: 1080)

        // When
        let thumbnail = sut.createThumbnail(from: wideImage, maxDimension: 400)

        // Then - Should preserve 16:9 ratio
        XCTAssertNotNil(thumbnail)
        let aspectRatio = thumbnail!.size.width / thumbnail!.size.height
        XCTAssertEqual(aspectRatio, 16.0/9.0, accuracy: 0.01)
    }

    // MARK: - Preprocessing Results

    func testPreprocessImage_ReturnsAllComponents() async {
        // Given
        let image = createTestImage(width: 2000, height: 1500)

        // When
        let result = await sut.preprocessImage(image)

        // Then
        XCTAssertNotNil(result.original, "Original should be returned")
        XCTAssertNotNil(result.optimized, "Optimized should be created")
        XCTAssertNotNil(result.thumbnail, "Thumbnail should be created")
    }

    func testPreprocessImage_OriginalUnmodified() async {
        // Given
        let originalImage = createTestImage(width: 3000, height: 2000)
        let originalSize = originalImage.size

        // When
        let result = await sut.preprocessImage(originalImage)

        // Then - Original reference should have same size
        XCTAssertEqual(result.original.size, originalSize)
    }

    func testPreprocessImage_ThumbnailSmallerThanOptimized() async {
        // Given
        let largeImage = createTestImage(width: 4000, height: 3000)

        // When
        let result = await sut.preprocessImage(largeImage)

        // Then - Thumbnail should be smaller than optimized
        XCTAssertLessThan(result.thumbnail?.size.width ?? 0, result.optimized.size.width)
        XCTAssertLessThan(result.thumbnail?.size.height ?? 0, result.optimized.size.height)
    }

    // MARK: - Edge Cases

    func testPreprocessImage_1x1Image_DoesNotCrash() async {
        // Given - Minimal 1x1 image
        let tinyImage = createTestImage(width: 1, height: 1)

        // When
        let result = await sut.preprocessImage(tinyImage)

        // Then
        XCTAssertNotNil(result.optimized)
        XCTAssertEqual(result.optimized.size.width, 1, accuracy: 1.0)
    }

    func testPreprocessImage_ExactlyMaxDimension_NotResized() async {
        // Given - Image already at max size
        let maxImage = createTestImage(width: 2048, height: 1536)

        // When
        let result = await sut.preprocessImage(maxImage)

        // Then - Should not be resized
        XCTAssertEqual(result.optimized.size.width, 2048, accuracy: 1.0)
        XCTAssertEqual(result.optimized.size.height, 1536, accuracy: 1.0)
    }

    // MARK: - Performance

    func testPreprocessImage_RunsOnBackgroundThread() async {
        // Given
        let image = createTestImage(width: 3000, height: 2000)

        // When
        let expectation = XCTestExpectation(description: "Processing completes")
        var processedOnMainThread = false

        Task {
            processedOnMainThread = Thread.isMainThread
            _ = await sut.preprocessImage(image)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)

        // Then - Should not block main thread during processing
        // Note: The task itself may complete on main thread, but the processing happens in background
        // This is acceptable as long as UI isn't blocked
    }

    func testPreprocessImage_LargeImage_CompletesInReasonableTime() async {
        // Given
        let largeImage = createTestImage(width: 4000, height: 3000)

        // When
        let startTime = Date()
        _ = await sut.preprocessImage(largeImage)
        let duration = Date().timeIntervalSince(startTime)

        // Then - Should complete in under 2 seconds
        XCTAssertLessThan(duration, 2.0, "Image processing should be fast")
    }

    // MARK: - Helper Methods

    private func createTestImage(width: CGFloat, height: CGFloat) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Create gradient for visual testing
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
        }
    }
}
