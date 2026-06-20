import SwiftUI

struct WorkoutPicker: View {
    let candidates: [TodayWorkoutCandidate]
    @Binding var selectedCandidateID: String?
    let onSelect: ((TodayWorkoutCandidate) -> Void)?

    init(
        candidates: [TodayWorkoutCandidate],
        selectedCandidateID: Binding<String?>,
        onSelect: ((TodayWorkoutCandidate) -> Void)? = nil
    ) {
        self.candidates = candidates
        self._selectedCandidateID = selectedCandidateID
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("选择今日要同步的训练")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(candidates) { candidate in
                Button {
                    selectedCandidateID = candidate.id
                    onSelect?(candidate)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.displayTitle)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppTheme.primaryText)
                            Text(candidate.displaySubtitle)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        if selectedCandidateID == candidate.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .padding(16)
                    .background(
                        selectedCandidateID == candidate.id
                            ? Color.white
                            : AppTheme.chipBackground
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                selectedCandidateID == candidate.id ? AppTheme.accent : AppTheme.divider,
                                lineWidth: selectedCandidateID == candidate.id ? 1.5 : 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
