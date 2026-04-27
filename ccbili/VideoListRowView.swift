import SwiftUI

struct VideoListRowView: View {
    let title: String
    let subtitle: String
    let accessoryText: String?
    let coverURL: URL?

    init(
        title: String,
        subtitle: String,
        accessoryText: String? = nil,
        coverURL: URL? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessoryText = accessoryText
        self.coverURL = coverURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RemoteImageView(
                url: coverURL,
                placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.quaternary.opacity(0.25))
                        ProgressView()
                    }
                },
                failureView: { errorText in
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.quaternary.opacity(0.25))

                        VStack(spacing: 6) {
                            Image(systemName: "photo")
                                .font(.title3)
                                .foregroundStyle(.secondary)

                            Text(errorText)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .padding(.horizontal, 6)
                        }
                    }
                }
            )
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
    }
}
