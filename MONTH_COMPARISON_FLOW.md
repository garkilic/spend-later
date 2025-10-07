# Month-to-Month Comparison Data Flow

## Overview
The app now has comprehensive month-to-month comparison features that are fully tied to actual user input data.

## Data Flow Architecture

### 1. Item Input → Storage
- User adds item via `AddItemViewModel`
- `WantedItemEntity` created with:
  - `title`, `price`, `notes`, `tags`, `imagePath`, `productURL`
  - `createdAt` timestamp
  - `monthKey` (e.g., "2025-10") derived from creation date
  - `status` (initially `.active`)

### 2. Month Rollover → Summary Creation
- `MonthRepository.rollIfNeeded()` checks if previous month needs summary
- `createSummary(for: monthKey, with: items)` aggregates all items from that month:
  ```swift
  summary.totalSaved = items.reduce(0) { $0 + item.price }
  summary.itemCount = items.count
  for item in items {
      item.summary = summary  // Links items to summary
  }
  ```
- Creates `MonthSummaryEntity` with:
  - `monthKey`: Unique month identifier
  - `totalSaved`: Sum of ALL item prices from that month
  - `itemCount`: Count of items resisted
  - `winnerItemId`: UUID of winner (set during spin)
  - `closedAt`: Timestamp when month was closed
  - `items`: Core Data relationship to actual `WantedItemEntity` objects

### 3. Monthly Spin → Winner Selection
- `MonthCloseoutViewModel.drawWinner()`:
  - Randomly selects from `summary.wantedItems` (actual items)
  - Sets winner status to `.redeemed`
  - Sets all others to `.skipped`
  - Stores `winnerItemId` in summary
  - Sets `closedAt` timestamp
  - Saves to Core Data

### 4. Display Layer
All views fetch REAL data from Core Data:

#### MonthDetailView
- Shows `summary.totalSaved` (calculated from actual items)
- Shows `summary.itemCount` (count of actual items)
- Shows average price: `items.reduce(0) { $0 + item.price } / count`
- Lists ALL items via `viewModel.items(for: summary.id)` which fetches:
  ```swift
  summary.wantedItems.map { entity in
      WantedItemDisplay(
          id: entity.id,
          title: entity.title,
          price: entity.price,
          // ... all actual entity data
      )
  }
  ```

#### MonthComparisonView
- Compares TWO `MonthSummaryEntity` objects
- All metrics calculated from actual stored data:
  - **Total Saved**: Direct from `summary.totalSaved`
  - **Item Count**: Direct from `summary.itemCount`
  - **Average Price**: Calculated from `summary.wantedItems`
  - **Percent Change**: `(current - previous) / previous * 100`
- Chart displays actual totals side-by-side
- Performance analysis based on real differences

#### HistoryView
- Shows list of all `MonthSummaryEntity` objects
- Each row displays:
  - Month name from `monthKey`
  - Total saved from actual summary
  - Item count from actual summary
  - Status (closed/active) from `closedAt`

## Data Integrity Guarantees

### 1. Items → Summary Link
- Core Data relationship: `WantedItemEntity.summary → MonthSummaryEntity`
- When summary created: `item.summary = summary`
- Fetching items: `summary.wantedItems` returns actual entities

### 2. Calculations Always From Source
```swift
// MonthRepository.createSummary
let total = items.reduce(Decimal.zero) { $0 + item.price.decimalValue }
summary.totalSaved = NSDecimalNumber(decimal: total)
summary.itemCount = Int32(items.count)
```

### 3. No Cached/Duplicated Data
- Summary stores ONLY aggregates (total, count)
- Full item data stays in `WantedItemEntity`
- Retrieving items: Always queries Core Data relationships
- Tax calculations: Applied at display time from settings

### 4. Historical Accuracy
- `closedAt` timestamp preserves when month ended
- `winnerItemId` preserves exact winner
- All items maintain their original:
  - Price (as entered by user)
  - Title, notes, tags
  - Creation timestamp
  - Image path

## User Journey Example

1. **October 2025**: User adds 10 items ($500 total)
   - Each stored as `WantedItemEntity` with `monthKey: "2025-10"`

2. **November 1, 2025**: App auto-creates summary
   - `MonthRepository.rollIfNeeded()` runs
   - Creates `MonthSummaryEntity`:
     - `monthKey: "2025-10"`
     - `totalSaved: $500` (sum of 10 items)
     - `itemCount: 10`
     - Links all 10 items to summary

3. **User spins**: Winner selected
   - Updates winner item status to `.redeemed`
   - Sets `summary.winnerItemId`
   - Sets `summary.closedAt`

4. **Viewing history**:
   - Tap October → `MonthDetailView`
   - See: $500 saved, 10 items, winner details
   - All data from original items

5. **Comparing months**:
   - Tap "Compare" → Select September
   - See: October vs September totals
   - Percent change calculated from actual totals
   - Both based on real user input

## Key Files

- **Data Models**: `MonthSummaryEntity.swift`, `WantedItemEntity.swift`
- **Repository**: `MonthRepository.swift` (aggregation logic)
- **ViewModels**: `HistoryViewModel.swift`, `MonthCloseoutViewModel.swift`
- **Views**:
  - `MonthDetailView.swift` (enhanced with stats)
  - `MonthComparisonView.swift` (NEW - side-by-side comparison)
  - `HistoryView.swift` (monthly summary navigation)

## Verification

To verify data integrity, check:
1. `MonthRepository.createSummary()` - aggregates from items
2. `HistoryViewModel.items(for: summaryId)` - fetches actual items
3. `MonthSummaryEntity.wantedItems` - Core Data relationship
4. All display calculations use source data, never cached values
