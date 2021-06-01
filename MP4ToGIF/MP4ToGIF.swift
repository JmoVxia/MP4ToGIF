//
//  MP4ToGIF.swift
//  MP4ToGIF
//
//  Created by Chen JmoVxia on 2021/5/27.
//  Copyright © 2021 Chen JmoVxia. All rights reserved.
//

import Cocoa
import Foundation
import AVFoundation

class MP4ToGIF {
    private var videoUrl: URL!
    init(videoUrl: URL) {
        self.videoUrl = videoUrl
    }
    func convertAndExport(to url: URL, cappedResolution: CGFloat?, desiredFrameRate: CGFloat?, completion: ((Bool) -> ())) {
        var isSuccess: Bool = false
        defer {
            completion(isSuccess)
        }
        // Do the converties
        let asset = AVURLAsset(url: videoUrl)
        guard let reader = try? AVAssetReader(asset: asset),
              let videoTrack = asset.tracks(withMediaType: .video).first
        else {
            return
        }

        let videoSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        // Restrict it to 480p (max in either dimension), it's a GIF, no need to have it in crazy 1080p (saves encoding time a lot, too)
        let aspectRatio = videoSize.width / videoSize.height

        let duration: CGFloat = CGFloat(asset.duration.seconds)
        let nominalFrameRate = CGFloat(videoTrack.nominalFrameRate)
        let nominalTotalFrames = Int(round(duration * nominalFrameRate))

        let resultingSize: CGSize = {
            if let cappedResolution = cappedResolution {
                if videoSize.width > videoSize.height {
                    let cappedWidth = round(min(cappedResolution, videoSize.width))
                    return CGSize(width: cappedWidth, height: round(cappedWidth / aspectRatio))
                } else {
                    let cappedHeight = round(min(cappedResolution, videoSize.height))
                    return CGSize(width: round(cappedHeight * aspectRatio), height: cappedHeight)
                }
            }else {
                return videoSize
            }
        }()

        // In order to convert from, say 30 FPS to 20, we'd need to remove 1/3 of the frames, this applies that math and decides which frames to remove/not process
        let framesToRemove: [Int] = {
            // Ensure the actual/nominal frame rate isn't already lower than the desired, in which case don't even worry about it
            if let desiredFrameRate = desiredFrameRate, desiredFrameRate < nominalFrameRate {
                let percentageOfFramesToRemove = 1.0 - (desiredFrameRate / nominalFrameRate)
                let totalFramesToRemove = Int(round(CGFloat(nominalTotalFrames) * percentageOfFramesToRemove))

                // We should remove a frame every `frameRemovalInterval` frames…
                // Since we can't remove e.g.: the 3.7th frame, round that up to 4, and we'd remove the 4th frame, then the 7.4th -> 7th, etc.
                let frameRemovalInterval = CGFloat(nominalTotalFrames) / CGFloat(totalFramesToRemove)
                var framesToRemove: [Int] = []

                var sum: CGFloat = 0.0

                while sum <= CGFloat(nominalTotalFrames) {
                    sum += frameRemovalInterval
                    if sum > CGFloat(nominalTotalFrames) { break }
                    let roundedFrameToRemove = Int(round(sum))
                    framesToRemove.append(roundedFrameToRemove)
                }
                return framesToRemove
            } else {
                return []
            }
        }()

        let totalFrames = nominalTotalFrames - framesToRemove.count

        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: resultingSize.width,
            kCVPixelBufferHeightKey as String: resultingSize.height
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)

        reader.add(readerOutput)
        reader.startReading()


        let delayBetweenFrames: CGFloat = 1.0 / min(desiredFrameRate ?? nominalFrameRate, nominalFrameRate)

        print("Nominal total frames: \(nominalTotalFrames), totalFramesUsed: \(totalFrames), totalFramesToRemove: \(framesToRemove.count), nominalFrameRate: \(nominalFrameRate), delayBetweenFrames: \(delayBetweenFrames)")

        let fileProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0
            ]
        ]

        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime: delayBetweenFrames
            ]
        ]
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeGIF, totalFrames, nil) else {
            return
        }

        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        var framesCompleted = 0
        var currentFrameIndex = 0
        
        while currentFrameIndex < nominalTotalFrames {
            if let sample = readerOutput.copyNextSampleBuffer() {
                currentFrameIndex += 1
                if framesToRemove.contains(currentFrameIndex) {
                    continue
                }
                // Create it as an optional and manually nil it out every time it's finished otherwise weird Swift bug where memory will balloon enormously (see https://twitter.com/ChristianSelig/status/1241572433095770114)
                var cgImage: CGImage? = self.cgImageFromSampleBuffer(sample)
                
                operationQueue.addOperation {
                    framesCompleted += 1
                    if let cgImage = cgImage {
                        CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
                    }
                    cgImage = nil
                    
                    //                    let progress = CGFloat(framesCompleted) / CGFloat(totalFrames)
                    
                    // GIF progress is a little fudged so it works with downloading progress reports
                    //                    let progressToReport = Int(progress * 100.0)
                    //                    print(progressToReport)
                }
            }
        }
        operationQueue.waitUntilAllOperationsAreFinished()
        isSuccess = CGImageDestinationFinalize(destination)
    }
}
extension MP4ToGIF {
    private func cgImageFromSampleBuffer(_ buffer: CMSampleBuffer) -> CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
        
        let image = context.makeImage()
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

        return image
    }
}
