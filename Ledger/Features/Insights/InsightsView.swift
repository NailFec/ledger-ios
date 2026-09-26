import SwiftUI

struct InsightsView: View {
    var body: some View {
        List {
            Section(Copy.Insights.yearHeatmap) {
                Text(Copy.Insights.comingSoon)
                    .foregroundStyle(.secondary)
            }
            Section(Copy.Insights.breakdownPie) {
                Text(Copy.Insights.comingSoon)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Copy.Navigation.insights)
    }
}
