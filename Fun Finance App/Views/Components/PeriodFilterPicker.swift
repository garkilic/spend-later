import SwiftUI

struct PeriodFilterPicker: View {
    @Binding var selectedPeriod: FilterPeriod

    var body: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(FilterPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Filter by time period")
    }
}

#if DEBUG
#Preview {
    struct PreviewWrapper: View {
        @State private var period: FilterPeriod = .month

        var body: some View {
            VStack {
                PeriodFilterPicker(selectedPeriod: $period)
                    .padding()

                Text("Selected: \(period.rawValue)")
            }
        }
    }

    return PreviewWrapper()
}
#endif
