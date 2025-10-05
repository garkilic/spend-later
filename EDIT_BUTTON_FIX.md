# Edit Button Fix

## Issue
Edit button was not visible in ItemDetailView when opening saved items.

## Root Cause
ItemDetailView was being presented as a sheet without a NavigationStack wrapper. The toolbar items (including the Edit button) require a NavigationStack to display properly in modal presentations.

## Solution
Wrapped ItemDetailView in NavigationStack when presenting as a sheet.

### Files Modified

#### 1. DashboardView.swift (Lines 352-364)
```swift
func detailSheet(for item: WantedItemDisplay) -> some View {
    let detailViewModel = makeDetailViewModel(item)
    return NavigationStack {  // ← Added NavigationStack wrapper
        ItemDetailView(viewModel: detailViewModel,
                      imageProvider: { viewModel.image(for: $0) }) { deleted in
            // ...
        }
    }
}
```

#### 2. HistoryView.swift (Lines 102-114)
```swift
func detailSheet(for item: WantedItemDisplay) -> some View {
    let detailViewModel = makeDetailViewModel(item)
    return NavigationStack {  // ← Added NavigationStack wrapper
        ItemDetailView(viewModel: detailViewModel,
                      imageProvider: { viewModel.image(for: $0) }) { deleted in
            // ...
        }
    }
}
```

## Result
✅ Edit button now visible in top right corner
✅ Cancel button appears when in edit mode
✅ Save button replaces Edit when editing
✅ All toolbar functionality works correctly

## Build Status
✅ **BUILD SUCCEEDED**

## Testing
- Open any saved item from Dashboard
- Open any saved item from History
- Verify "Edit" button appears in top right
- Tap Edit → Verify "Cancel" and "Save" buttons appear
- All editing features now accessible
