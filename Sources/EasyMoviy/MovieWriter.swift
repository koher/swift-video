#if canImport(AVFoundation)
import AVFoundation
import EasyImagy
import Foundation

public class MovieWriter<Pixel : AVAssetPixel> {
    private struct LazyState {
        let assetWriterInput: AVAssetWriterInput
        let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
        let pixelBuffer: CVPixelBuffer
        
        let width: Int
        let height: Int
    }
    
    private let assetWriter: AVAssetWriter
    private var state: LazyState?
    private var finished: Bool = false
    
    private var lastTime: CMTime?
    
    public init(url: URL, type: AVFileType) throws {
        self.assetWriter = try AVAssetWriter(outputURL: url, fileType: type)
    }
    
    @_specialize(exported: true, kind: partial, where I == Image<RGBA<UInt8>>)
    @_specialize(exported: true, kind: partial, where I == Image<PremultipliedRGBA<UInt8>>)
    @_specialize(exported: true, kind: partial, where I == Image<UInt8>)
    public func write<I>(_ image: I, time: CMTime) throws where I : ImageProtocol, I.Pixel == Pixel {
        if let state = self.state {
            precondition(image.width == state.width && image.height == state.height, "The size of the frame (\(image.width), \(image.height)) must be equal to the first frame (\(state.width), \(state.height)).")
        } else {
            precondition(image.width > 0 && image.height > 0, "The size of the frame (\(image.width), \(image.height)) cannot be zero.")
            
            let assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecH264,
                AVVideoWidthKey: NSNumber(value: image.width),
                AVVideoHeightKey: NSNumber(value: image.height),
            ])
            
            let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Pixel.recommendedFormat,
                kCVPixelBufferWidthKey as String: NSNumber(value: image.width),
                kCVPixelBufferHeightKey as String: NSNumber(value: image.height)
            ])

            assetWriter.add(assetWriterInput)
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: time)
            
            var pixelBuffer: CVPixelBuffer?
            do {
                let resultCode = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)
                guard resultCode == 0 else {
                    throw MovieWriterError(resultCode: resultCode)
                }
            }
            assert(pixelBuffer != nil)
            
            self.state = LazyState(
                assetWriterInput: assetWriterInput,
                pixelBufferAdaptor: pixelBufferAdaptor,
                pixelBuffer: pixelBuffer!,
                width: image.width,
                height: image.height
            )
        }
        
        let state = self.state! // `self.state` is never `nil` here.
        let pixelBuffer = state.pixelBuffer

        do {
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0)) }

            assert(!CVPixelBufferIsPlanar(pixelBuffer))
            assert(CVPixelBufferGetPlaneCount(pixelBuffer) == 0)
            assert(Int(CVPixelBufferGetBytesPerRow(pixelBuffer)) == MemoryLayout<Pixel>.size * image.width)
            
            let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!
            let pointer = baseAddress.bindMemory(to: Pixel.self, capacity: image.count)
            do {
                var pOut = pointer
                for pixel in image {
                    var pixel = pixel
                    Pixel.invert(&pixel)
                    pOut.pointee = pixel
                    pOut += 1
                }
            }
        }
        
        state.pixelBufferAdaptor.append(state.pixelBuffer, withPresentationTime: time)
        
        lastTime = time
    }
    
    @_specialize(exported: true, kind: partial, where I == Image<RGBA<UInt8>>)
    @_specialize(exported: true, kind: partial, where I == Image<PremultipliedRGBA<UInt8>>)
    @_specialize(exported: true, kind: partial, where I == Image<UInt8>)
    public func write<I>(_ image: I, time: TimeInterval) throws where I : ImageProtocol, I.Pixel == Pixel {
        try write(image, time: CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
    }
    
    @_specialize(exported: true, kind: partial, where I == Image<RGBA<UInt8>>)
    @_specialize(exported: true, kind: partial, where I == Image<PremultipliedRGBA<UInt8>>)
    @_specialize(exported: true, kind: partial, where I == Image<UInt8>)
    public func write<I>(_ image: I, interval: TimeInterval) throws where I : ImageProtocol, I.Pixel == Pixel {
        guard let lastTime = self.lastTime else {
            try write(image, time: 0.0)
            return
        }
        try write(image, time: lastTime.seconds + interval)
    }

    public func finishWriting(completionHandler: @escaping () -> Void) {
        guard !finished else { return }
        guard let state = self.state else { return }
        
        state.assetWriterInput.markAsFinished()
        assetWriter.endSession(atSourceTime: lastTime!)
        assetWriter.finishWriting(completionHandler: completionHandler)
        
        self.state = nil
        finished = true
    }
}

public struct MovieWriterError : Error {
    public let resultCode: CVReturn
    
    fileprivate init(resultCode: CVReturn) {
        self.resultCode = resultCode
    }
}

#endif
