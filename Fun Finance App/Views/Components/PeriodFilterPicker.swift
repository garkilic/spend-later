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
    @Previewable @State var period: FilterPeriod = .month

    VStack {
        PeriodFilterPicker(selectedPeriod: $period)
            .padding()

        Text("Selected: \(period.rawValue)")
    }
}
#endif
