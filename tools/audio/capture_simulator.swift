// Root-only native Simulator audio and optional window video. No microphone.
import AppKit
import AVFAudio
import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import ScreenCaptureKit

struct CaptureError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

struct Options {
    let pid: pid_t
    let seconds: Int
    let output: URL
    let simulator: URL
    let windowID: CGWindowID?
    let video: URL?

    init(arguments: [String]) throws {
        let usage = """
        Usage: capture-simulator --runtime-owner root --pid PID --seconds 1..90 \
        --simulator "/absolute/path/to/Playdate Simulator" \
        --output /absolute/path/outside/git/native.wav
        Optional video: --window-id WINDOW_ID --video-output /absolute/path/native.mp4
        """
        var values: [String: String] = [:]
        let keys = ["--runtime-owner", "--pid", "--seconds", "--simulator", "--output", "--window-id", "--video-output"]
        var index = 0
        while index < arguments.count {
            let key = arguments[index]
            guard keys.contains(key), values[key] == nil, index + 1 < arguments.count else {
                throw CaptureError(message: usage)
            }
            values[key] = arguments[index + 1]
            index += 2
        }
        guard (values.count == 5 || values.count == 7),
              values["--runtime-owner"] == "root",
              let pid = Int32(values["--pid"] ?? ""), pid > 0,
              let seconds = Int(values["--seconds"] ?? ""), (1...90).contains(seconds),
              let path = values["--output"], path.hasPrefix("/"),
              let executable = values["--simulator"], executable.hasPrefix("/") else {
            throw CaptureError(message: usage)
        }
        self.pid = pid
        self.seconds = seconds
        output = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        simulator = URL(fileURLWithPath: executable).resolvingSymlinksInPath()

        if let window = values["--window-id"], let movie = values["--video-output"],
           let identifier = UInt32(window), movie.hasPrefix("/") {
            windowID = identifier
            video = URL(fileURLWithPath: movie).resolvingSymlinksInPath()
        } else if values["--window-id"] == nil && values["--video-output"] == nil {
            windowID = nil
            video = nil
        } else {
            throw CaptureError(message: "Video requires both --window-id and an absolute --video-output path.")
        }
        try Self.checkOutput(output, extension: "wav")
        if let video {
            try Self.checkOutput(video, extension: "mp4")
        }
    }

    private static func checkOutput(_ output: URL, extension suffix: String) throws {
        let files = FileManager.default
        guard output.pathExtension.lowercased() == suffix,
              files.fileExists(atPath: output.deletingLastPathComponent().path),
              !files.fileExists(atPath: output.path) else {
            throw CaptureError(message: "Output must be a new .\(suffix) in an existing directory.")
        }
        var parent = output.deletingLastPathComponent()
        while true {
            if files.fileExists(atPath: parent.appendingPathComponent(".git").path) {
                throw CaptureError(message: "Recording path must be outside every Git checkout.")
            }
            let next = parent.deletingLastPathComponent()
            if next == parent {
                break
            }
            parent = next
        }
    }
}

// All mutable writer state is confined to the same serial sample queue.
final class AudioWriter: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "pokemon.simulator.audio-file")
    private let output: URL
    private let limit: AVAudioFramePosition
    private var file: AVAudioFile?
    private var format: AVAudioFormat?
    private var frames: AVAudioFramePosition = 0
    private var failure: Error?
    private var closed = false
    private let videoSize: (Int, Int)?
    private var videoFrames = 0
    private var firstVideoPTS: Double?
    private var lastVideoPTS: Double?

    init(output: URL, seconds: Int, videoSize: (Int, Int)?) {
        self.output = output
        limit = AVAudioFramePosition(seconds * 48000)
        self.videoSize = videoSize
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard !closed, failure == nil else {
            return
        }
        if type == .screen {
            observeVideo(sampleBuffer)
            return
        }
        guard type == .audio, frames < limit else {
            return
        }
        do {
            guard CMSampleBufferDataIsReady(sampleBuffer),
                  let description = CMSampleBufferGetFormatDescription(sampleBuffer) else {
                throw CaptureError(message: "ScreenCaptureKit returned an unready audio buffer.")
            }
            let inputFormat = AVAudioFormat(cmAudioFormatDescription: description)
            guard inputFormat.sampleRate == 48000, inputFormat.channelCount == 2 else {
                throw CaptureError(message: "Expected native capture buffers at 48000 Hz, stereo.")
            }
            if let format, !format.isEqual(inputFormat) {
                throw CaptureError(message: "Capture audio format changed during recording.")
            }
            let count = min(AVAudioFramePosition(CMSampleBufferGetNumSamples(sampleBuffer)), limit - frames)
            guard count > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(count)) else {
                throw CaptureError(message: "Cannot allocate the native PCM copy buffer.")
            }
            buffer.frameLength = AVAudioFrameCount(count)
            let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
                sampleBuffer, at: 0, frameCount: Int32(count), into: buffer.mutableAudioBufferList
            )
            guard status == noErr else {
                throw CaptureError(message: "Native PCM copy failed: OSStatus \(status).")
            }
            if file == nil {
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 48000,
                    AVNumberOfChannelsKey: 2,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false,
                ]
                file = try AVAudioFile(forWriting: output, settings: settings,
                                       commonFormat: inputFormat.commonFormat,
                                       interleaved: inputFormat.isInterleaved)
                format = inputFormat
                let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                print("FIRST_AUDIO pts=\(pts) host_uptime=\(ProcessInfo.processInfo.systemUptime)")
            }
            try file!.write(from: buffer)
            frames += count
        } catch {
            failure = error
        }
    }

    private func observeVideo(_ sample: CMSampleBuffer) {
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false)
            as? [[SCStreamFrameInfo: Any]]
        guard let status = attachments?.first?[.status] as? Int else {
            failure = CaptureError(message: "Window buffer has no frame status.")
            return
        }
        if status == SCFrameStatus.blank.rawValue || status == SCFrameStatus.suspended.rawValue {
            failure = CaptureError(message: "Window capture became blank or suspended.")
            return
        }
        guard status == SCFrameStatus.complete.rawValue else {
            return
        }
        guard let image = CMSampleBufferGetImageBuffer(sample), let expected = videoSize,
              CVPixelBufferGetWidth(image) == expected.0,
              CVPixelBufferGetHeight(image) == expected.1 else {
            failure = CaptureError(message: "Captured window dimensions differ from the requested native dimensions.")
            return
        }
        let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
        if firstVideoPTS == nil {
            firstVideoPTS = pts
            print("FIRST_VIDEO pts=\(pts) pixels=\(expected.0)x\(expected.1) host_uptime=\(ProcessInfo.processInfo.systemUptime)")
        }
        lastVideoPTS = pts
        videoFrames += 1
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        queue.async {
            self.failure = error
        }
    }

    func finish() throws -> AVAudioFramePosition {
        try queue.sync {
            closed = true
            file?.close()
            file = nil
            if let failure {
                throw failure
            }
            guard frames > 0 else {
                throw CaptureError(message: "No native audio buffers received; no accepted recording.")
            }
            if videoSize != nil {
                guard videoFrames > 0, let firstVideoPTS, let lastVideoPTS else {
                    throw CaptureError(message: "No complete window frames received.")
                }
                print("VIDEO frames=\(videoFrames) first_pts=\(firstVideoPTS) last_pts=\(lastVideoPTS)")
            }
            return frames
        }
    }
}

// Native recording output finalizes asynchronously after SCStream stops.
final class MovieStatus: NSObject, SCRecordingOutputDelegate, @unchecked Sendable {
    private let started = DispatchSemaphore(value: 0)
    private let finished = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var failure: Error?

    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        started.signal()
    }

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        finished.signal()
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        lock.withLock {
            failure = error
        }
        started.signal()
        finished.signal()
    }

    private func waitForSignal(start: Bool) -> Bool {
        let semaphore = start ? started : finished
        return semaphore.wait(timeout: .now() + 10) == .success
    }

    func wait(start: Bool) async throws {
        let success = await Task.detached {
            self.waitForSignal(start: start)
        }.value
        guard success else {
            throw CaptureError(message: "Native video recording start/finalization timed out.")
        }
        try lock.withLock {
            if let failure {
                throw failure
            }
        }
    }
}

@main
struct CaptureSimulator {
    @MainActor
    static func main() async {
        _ = NSApplication.shared
        do {
            let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
            try await capture(options)
        } catch {
            FileHandle.standardError.write(Data("Capture failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    @MainActor
    static func capture(_ options: Options) async throws {
        // A newly spawned Cocoa process can exist before AppKit registers it.
        // Keep the exact identity check, allowing that short startup interval.
        var registeredTarget: NSRunningApplication?
        for _ in 0..<50 {
            if let candidate = NSRunningApplication(processIdentifier: options.pid),
               !candidate.isTerminated,
               candidate.executableURL?.resolvingSymlinksInPath() == options.simulator,
               options.simulator.lastPathComponent == "Playdate Simulator" {
                registeredTarget = candidate
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        guard let target = registeredTarget else {
            throw CaptureError(message: "PID does not identify the exact expected Playdate Simulator executable.")
        }
        guard CGPreflightScreenCaptureAccess() else {
            throw CaptureError(message: "Screen Recording permission is required for this executable/launching host in System Settings > Privacy & Security. No permission request was made; grant access manually and rerun.")
        }
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        guard !target.isTerminated,
              let application = content.applications.first(where: { $0.processID == options.pid }),
              let display = content.displays.first else {
            throw CaptureError(message: "The requested PID or an active display is unavailable to ScreenCaptureKit.")
        }
        let windows = content.windows.filter { $0.owningApplication?.processID == options.pid }
        for window in windows {
            print("WINDOW id=\(window.windowID) title=\(window.title ?? "") points=\(window.frame.width)x\(window.frame.height)")
        }
        let filter: SCContentFilter
        if let windowID = options.windowID {
            guard let window = windows.first(where: { $0.windowID == windowID }), window.isOnScreen else {
                throw CaptureError(message: "Requested window ID is not an onscreen window owned by the exact PID. See WINDOW candidates above.")
            }
            filter = SCContentFilter(desktopIndependentWindow: window)
        } else {
            filter = SCContentFilter(display: display, including: [application], exceptingWindows: [])
        }
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.captureMicrophone = false
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 48000
        configuration.channelCount = 2
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        configuration.showsCursor = false

        var videoSize: (Int, Int)?
        if options.video != nil {
            configuration.ignoreShadowsSingleWindow = true
            configuration.captureResolution = .best
            configuration.scalesToFit = false
            configuration.preservesAspectRatio = true
            let width = Int(ceil(filter.contentRect.width * Double(filter.pointPixelScale)))
            let height = Int(ceil(filter.contentRect.height * Double(filter.pointPixelScale)))
            guard width > 0, height > 0 else {
                throw CaptureError(message: "Window has no native pixel extent.")
            }
            configuration.width = width
            configuration.height = height
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            videoSize = (width, height)
            print("VIDEO_CONFIG window_id=\(options.windowID!) pixels=\(width)x\(height) scale=\(filter.pointPixelScale) max_fps=60")
        }
        let writer = AudioWriter(output: options.output, seconds: options.seconds, videoSize: videoSize)
        let stream = SCStream(filter: filter, configuration: configuration, delegate: writer)
        try stream.addStreamOutput(writer, type: .audio, sampleHandlerQueue: writer.queue)
        // No microphone output is ever registered.
        let movieStatus = MovieStatus()
        var movie: SCRecordingOutput?
        if let video = options.video {
            try stream.addStreamOutput(writer, type: .screen, sampleHandlerQueue: writer.queue)
            let recording = SCRecordingOutputConfiguration()
            recording.outputURL = video
            recording.videoCodecType = .h264
            recording.outputFileType = .mp4
            guard recording.availableVideoCodecTypes.contains(.h264),
                  recording.availableOutputFileTypes.contains(.mp4) else {
                throw CaptureError(message: "Native H.264/MP4 recording output is unavailable.")
            }
            movie = SCRecordingOutput(configuration: recording, delegate: movieStatus)
            try stream.addRecordingOutput(movie!)
        }
        do {
            try await stream.startCapture()
            if movie != nil {
                try await movieStatus.wait(start: true)
            }
            print("CAPTURING pid=\(options.pid) seconds=\(options.seconds) output=\(options.output.path)")
            try await Task.sleep(nanoseconds: UInt64(options.seconds) * 1_000_000_000)
            try await stream.stopCapture()
            if movie != nil {
                try await movieStatus.wait(start: false)
                try stream.removeStreamOutput(writer, type: .screen)
            }
            try stream.removeStreamOutput(writer, type: .audio)
        } catch {
            try? await stream.stopCapture()
            _ = try? writer.finish()
            throw error
        }
        let frames = try writer.finish()
        guard !target.isTerminated else {
            throw CaptureError(message: "Target Simulator exited during capture; retained WAV is incomplete.")
        }
        print("WROTE frames=\(frames) seconds=\(Double(frames) / 48000) format=PCM16LE/48000Hz/stereo")
        if let movie {
            guard movie.recordedFileSize > 0, CMTimeGetSeconds(movie.recordedDuration) > 0 else {
                throw CaptureError(message: "Native recording output finalized without video data.")
            }
            let asset = AVURLAsset(url: options.video!)
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            guard videoTracks.count == 1, !audioTracks.isEmpty, let expected = videoSize else {
                throw CaptureError(message: "Final movie lacks the expected native video/audio tracks.")
            }
            let size = try await videoTracks[0].load(.naturalSize)
            let range = try await videoTracks[0].load(.timeRange)
            guard Int(size.width) == expected.0, Int(size.height) == expected.1 else {
                throw CaptureError(message: "Encoded movie dimensions differ from the native capture canvas.")
            }
            print("MOVIE pixels=\(Int(size.width))x\(Int(size.height)) video_start=\(CMTimeGetSeconds(range.start)) video_end=\(CMTimeGetSeconds(range.end))")
            print("MOVIE seconds=\(CMTimeGetSeconds(movie.recordedDuration)) bytes=\(movie.recordedFileSize) path=\(options.video!.path)")
        }
    }
}
