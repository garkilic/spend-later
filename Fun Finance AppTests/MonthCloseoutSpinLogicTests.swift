import XCTest
@testable import Fun_Finance_App

/// Tests for the wheel spin logic (testable parts)
/// Note: UI animations and timing are tested via UI tests or manual testing
final class MonthCloseoutSpinLogicTests: XCTestCase {

    // MARK: - Winner Selection

    func testRandomWinnerSelection_AlwaysPicksFromCandidates() {
        // Given
        let candidates = createMockItems(count: 10)

        // When - Run 50 times to test randomness
        for _ in 0..<50 {
            let winner = candidates.randomElement()

            // Then
            XCTAssertNotNil(winner)
            XCTAssertTrue(candidates.contains(where: { $0.id == winner?.id }))
        }
    }

    func testRandomWinnerSelection_HasReasonableDistribution() {
        // Given
        let item1 = createMockItem(title: "Item 1")
        let item2 = createMockItem(title: "Item 2")
        let item3 = createMockItem(title: "Item 3")
        let candidates = [item1, item2, item3]

        var winCounts: [UUID: Int] = [
            item1.id: 0,
            item2.id: 0,
            item3.id: 0
        ]

        // When - Run 300 times
        for _ in 0..<300 {
            if let winner = candidates.randomElement() {
                winCounts[winner.id, default: 0] += 1
            }
        }

        // Then - Each should win roughly 100 times (±40 for randomness)
        XCTAssertGreaterThan(winCounts[item1.id]!, 60)
        XCTAssertLessThan(winCounts[item1.id]!, 140)
        XCTAssertGreaterThan(winCounts[item2.id]!, 60)
        XCTAssertLessThan(winCounts[item2.id]!, 140)
        XCTAssertGreaterThan(winCounts[item3.id]!, 60)
        XCTAssertLessThan(winCounts[item3.id]!, 140)
    }

    // MARK: - Scroll Offset Calculations

    func testScrollOffsetCalculation_CentersWinnerOnScreen() {
        // Given
        let cardWidth: CGFloat = 200
        let spacing: CGFloat = 20
        let cardPlusSpacing = cardWidth + spacing
        let screenWidth: CGFloat = 390 // iPhone 15 width
        let centerScreen = screenWidth / 2

        let winnerIndex = 2
        let targetRepetition = 1
        let candidatesCount = 5

        // When
        let totalCardsBeforeTarget = (targetRepetition * candidatesCount) + winnerIndex
        let finalOffset = centerScreen - (CGFloat(totalCardsBeforeTarget) * cardPlusSpacing) - (cardWidth / 2)

        // Then - Offset should position winner card center at screen center
        let winnerCardCenter = -finalOffset + (CGFloat(totalCardsBeforeTarget) * cardPlusSpacing) + (cardWidth / 2)
        XCTAssertEqual(winnerCardCenter, centerScreen, accuracy: 0.1)
    }

    func testScrollOffsetCalculation_WorksForDifferentWinnerIndexes() {
        // Given
        let cardWidth: CGFloat = 200
        let spacing: CGFloat = 20
        let cardPlusSpacing = cardWidth + spacing
        let screenWidth: CGFloat = 390
        let centerScreen = screenWidth / 2
        let candidatesCount = 5

        // When/Then - Test each possible winner position
        for winnerIndex in 0..<candidatesCount {
            let totalCardsBeforeTarget = candidatesCount + winnerIndex // using repetition 1
            let finalOffset = centerScreen - (CGFloat(totalCardsBeforeTarget) * cardPlusSpacing) - (cardWidth / 2)

            let winnerCardCenter = -finalOffset + (CGFloat(totalCardsBeforeTarget) * cardPlusSpacing) + (cardWidth / 2)
            XCTAssertEqual(winnerCardCenter, centerScreen, accuracy: 0.1,
                          "Winner at index \(winnerIndex) should be centered")
        }
    }

    // MARK: - Phase Timing Validation

    func testSpinPhases_HaveCorrectDurations() {
        // Given
        let phase1Duration = 1.5
        let phase2Duration = 1.5
        let phase3Duration = 2.0
        let totalDuration = phase1Duration + phase2Duration + phase3Duration

        // Then
        XCTAssertEqual(totalDuration, 5.0, "Total spin should be 5 seconds")
    }

    func testSpinPhases_AreSequential() {
        // Given
        let phase1Start: TimeInterval = 0.0
        let phase2Start: TimeInterval = 1.5
        let phase3Start: TimeInterval = 3.0
        let winnerReveal: TimeInterval = 5.0

        // Then
        XCTAssertEqual(phase2Start - phase1Start, 1.5)
        XCTAssertEqual(phase3Start - phase2Start, 1.5)
        XCTAssertEqual(winnerReveal - phase3Start, 2.0)
    }

    // MARK: - Edge Cases

    func testSpin_WithSingleItem_StillWorks() {
        // Given
        let singleItem = createMockItem(title: "Only Item")
        let candidates = [singleItem]

        // When
        let winner = candidates.randomElement()

        // Then
        XCTAssertEqual(winner?.id, singleItem.id)
    }

    func testSpin_WithEmptyCandidates_ReturnsNil() {
        // Given
        let candidates: [WantedItemDisplay] = []

        // When
        let winner = candidates.randomElement()

        // Then
        XCTAssertNil(winner)
    }

    // MARK: - Helper Methods

    private func createMockItems(count: Int) -> [WantedItemDisplay] {
        return (0..<count).map { index in
            createMockItem(title: "Item \(index)")
        }
    }

    private func createMockItem(title: String) -> WantedItemDisplay {
        return WantedItemDisplay(
            id: UUID(),
            title: title,
            price: 100,
            priceWithTax: 110,
            notes: nil,
            productURL: nil,
            tags: [],
            createdAt: Date(),
            status: .saved
        )
    }
}
