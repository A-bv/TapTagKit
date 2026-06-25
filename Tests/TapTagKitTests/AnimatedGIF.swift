import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Minimal animated-GIF encoder built on ImageIO (no third-party dependencies).
/// Used by `ReadmeGIFTests` to render the README demo.
enum AnimatedGIF {

    struct Frame {
        let image: UIImage
        let delay: Double   // seconds
    }

    enum Failure: Error { case couldNotCreateDestination, couldNotFinalize }

    static func write(_ frames: [Frame], to url: URL, loopForever: Bool = true) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.gif.identifier as CFString, frames.count, nil)
        else { throw Failure.couldNotCreateDestination }

        let fileProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: loopForever ? 0 : 1
            ]
        ] as CFDictionary
        CGImageDestinationSetProperties(destination, fileProperties)

        for frame in frames {
            guard let cgImage = frame.image.cgImage else { continue }
            let frameProperties = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFUnclampedDelayTime: frame.delay
                ]
            ] as CFDictionary
            CGImageDestinationAddImage(destination, cgImage, frameProperties)
        }

        guard CGImageDestinationFinalize(destination) else { throw Failure.couldNotFinalize }
    }
}
