//
//  HistoryViewModel.swift
//  ccbili
//
//  Created by chuzu  on 2026/4/25.
//


import Foundation
import Observation

@Observable
final class HistoryViewModel {
    var items: [VideoItem] = []
    var isLoading = false
    var errorMessage: String?

    private let service = HistoryService()

    func load() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            items = try await service.fetchHistory(max: 30)
        } catch {
            errorMessage = error.localizedDescription
            items = []
        }
    }
}