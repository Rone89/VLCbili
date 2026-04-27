//
//  DashRemuxService.swift
//  ccbili
//
//  Created by chuzu  on 2026/4/26.
//

import Foundation

struct DashRemuxService {
    func remuxToMP4(
        videoURL: URL,
        audioURL: URL,
        headers: [String: String]
    ) async throws -> URL {
        throw APIError.serverMessage(
            """
            当前构建未接入 FFmpegKit，暂时无法播放 DASH 音视频分离流。

            如果要启用 DASH 合流播放，请先在 Xcode 中添加 FFmpegKit 依赖，
            然后再恢复 DashRemuxService 的 FFmpeg 实现。
            """
        )
    }
}
