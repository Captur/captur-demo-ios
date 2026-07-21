//
//  HomeView.swift
//  CapturDemo
//

import CapturSDK
import SwiftUI

struct HomeView: View {
    @ObservedObject var model: CaptureFlowModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if !CapturConfig.isConfigured {
                    apiKeyBanner
                }

                ForEach(UseCase.allCases) { useCase in
                    NavigationLink {
                        FlowView(model: model, useCase: useCase)
                    } label: {
                        useCaseCard(useCase)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text("CapturSDK \(CapturSDKMetadata.version)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Captur Demo")
        }
    }

    private var apiKeyBanner: some View {
        Label("Paste your API key into CapturConfig.swift to run the demo.",
              systemImage: "key.fill")
            .font(.callout)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private func useCaseCard(_ useCase: UseCase) -> some View {
        HStack(spacing: 16) {
            Image(systemName: useCase.systemImage)
                .font(.title)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(useCase.title)
                    .font(.headline)
                Text(useCase.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    HomeView(model: CaptureFlowModel())
}
