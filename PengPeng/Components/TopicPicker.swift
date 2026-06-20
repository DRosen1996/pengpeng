import SwiftUI

struct TopicPicker: View {
    let topics: [SportTopic]
    @Binding var selectedTopic: SportTopic?
    let onSelect: ((SportTopic) -> Void)?

    init(
        topics: [SportTopic],
        selectedTopic: Binding<SportTopic?>,
        onSelect: ((SportTopic) -> Void)? = nil
    ) {
        self.topics = topics
        self._selectedTopic = selectedTopic
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(topics) { topic in
                Button {
                    selectedTopic = topic
                    onSelect?(topic)
                } label: {
                    HStack {
                        Text(topic.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer()
                        if selectedTopic?.id == topic.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .padding(16)
                    .background(
                        selectedTopic?.id == topic.id
                            ? Color.white
                            : AppTheme.chipBackground
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                selectedTopic?.id == topic.id ? AppTheme.accent : AppTheme.divider,
                                lineWidth: selectedTopic?.id == topic.id ? 1.5 : 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
