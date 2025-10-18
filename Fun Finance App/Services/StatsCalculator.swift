import Foundation

/// Calculates interesting statistics and KPIs for the dashboard
@MainActor
final class StatsCalculator {

    // MARK: - Public Methods

    /// Calculate buyer's remorse prevented
    /// Industry research shows ~60% of impulse purchases are regretted
    func buyersRemorsePrevented(itemCount: Int) -> Int {
        let remorsePrevented = Double(itemCount) * 0.6
        return Int(round(remorsePrevented))
    }

    /// Calculate carbon footprint saved in kg CO2
    /// Average consumer product carbon footprint: ~5.5 kg CO2 per item
    /// Source: Environmental research on consumer goods lifecycle
    func carbonFootprintSaved(itemCount: Int) -> Double {
        let averageCO2PerProduct = 5.5 // kg CO2
        return Double(itemCount) * averageCO2PerProduct
    }

    /// Format carbon footprint for display
    func formatCarbonFootprint(_ kgCO2: Double) -> String {
        if kgCO2 >= 1000 {
            let tonnes = kgCO2 / 1000
            return String(format: "%.1f tonnes", tonnes)
        } else {
            return String(format: "%.0f kg", kgCO2)
        }
    }

    /// Get carbon footprint context (what it's equivalent to)
    func carbonFootprintContext(_ kgCO2: Double) -> String {
        // Context comparisons for understanding
        // Average car emits ~0.2 kg CO2 per km
        let kmDriven = kgCO2 / 0.2

        if kmDriven >= 100 {
            return "Equal to driving \(Int(kmDriven)) km"
        } else if kgCO2 >= 20 {
            let trees = Int(kgCO2 / 20) // One tree absorbs ~20kg CO2/year
            return "Saved what \(trees) tree\(trees == 1 ? "" : "s") absorb yearly"
        } else {
            return "Every bit helps the planet 🌍"
        }
    }

    /// Get buyer's remorse context message
    func buyersRemorseContext(prevented: Int, total: Int) -> String {
        if prevented == 0 {
            return "Keep tracking to prevent future regrets"
        } else if prevented == 1 {
            return "That's one less regret to carry"
        } else {
            return "Studies show 60% of impulse buys are regretted"
        }
    }
}
