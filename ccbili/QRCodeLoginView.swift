//
//  QRCodeLoginView.swift
//  ccbili
//
//  Created by chuzu  on 2026/4/25.
//


import SwiftUI

struct QRCodeLoginView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = QRCodeLoginViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("二维码登录") {
                    VStack(spacing: 16) {
                        if let qrCodeImageURL = viewModel.qrCodeImageURL {
                            AsyncImage(url: qrCodeImageURL) { phase in
                                switch phase {
                                case .empty:
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.gray.opacity(0.12))
                                        ProgressView()
                                    }

                                case .success(let image):
                                    image
                                        .resizable()
                                        .interpolation(.none)
                                        .scaledToFit()

                                case .failure:
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.gray.opacity(0.12))
                                        Image(systemName: "qrcode")
                                            .font(.largeTitle)
                                            .foregroundStyle(.secondary)
                                    }

                                @unknown default:
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.gray.opacity(0.12))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.gray.opacity(0.12))

                                if viewModel.isLoading {
                                    ProgressView()
                                } else {
                                    Image(systemName: "qrcode")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(height: 240)
                        }

                        Text(viewModel.statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button("刷新二维码") {
                            Task {
                                await viewModel.loadQRCode()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("说明") {
                    Text("请使用哔哩哔哩 App 扫描二维码，并在 App 内确认登录。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .task {
                if viewModel.qrCodeImageURL == nil {
                    await viewModel.loadQRCode()
                }
            }
            .onChange(of: viewModel.isLoginCompleted) { _, newValue in
                guard newValue else { return }

                Task {
                    await authManager.refreshLoginStatus()
                    dismiss()
                }
            }
            .onDisappear {
                viewModel.cancelPolling()
            }
        }
    }
}