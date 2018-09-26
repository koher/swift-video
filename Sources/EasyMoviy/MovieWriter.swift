#if canImport(AVFoundation)
import AVFoundation
import EasyImagy
import Foundation

public class MovieWriter<Pixel : AVAssetPixel> {
    private let assetWriter: AVAssetWriter
    private let assetWriterInput: AVAssetWriterInput
    private let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    private let pixelBuffer: CVPixelBuffer
    
    private let width: Int
    private let height: Int

    private var finished: Bool = false
    
    private var lastTime: CMTime?
    
    public init(url: URL, type: AVFileType, width: Int, height: Int) throws {
        precondition(width > 0, "`width` must be greater than 0: \(width)")
        precondition(height > 0, "`height` must be greater than 0: \(height)")

        let assetWriter = try AVAssetWriter(outputURL: url, fileType: type)
        
        let assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoWidthKey: NSNumber(value: width),
            AVVideoHeightKey: NSNumber(value: height),
        ])
        assetWriterInput.expectsMediaDataInRealTime = true
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Pixel.recommendedFormat,
            kCVPixelBufferWidthKey as String: NSNumber(value: width),
            kCVPixelBufferHeightKey as String: NSNumber(value: height)
        ])
        
        assetWriter.add(assetWriterInput)
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: CMTime.init(value: 0, timescale: 1))
        if assetWriter.status == .failed {
            throw MovieWriterError.illegalStatus(status: assetWriter.status, error: assetWriter.error!)
        }
        assert(pixelBufferAdaptor.pixelBufferPool != nil)
        
        var pixelBuffer: CVPixelBuffer?
        do {
            let resultCode = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)
            guard resultCode == 0 else {
                throw MovieWriterError.failedToCreatePixelBuffer(resultCode)
            }
        }
        assert(pixelBuffer != nil)
        
        self.assetWriter = assetWriter
        self.assetWriterInput = assetWriterInput
        self.pixelBufferAdaptor = pixelBufferAdaptor
        self.pixelBuffer = pixelBuffer!
        
        self.width = width
        self.height = height
    }
    
    @_specialize(exported: true, kind: partial, where I == Image<RGBA<UInt8>>)
    @_specialize(exported: true, kind: partial, where I == Image<PremultipliedRGBA<UInt8>>)
    @_specialize(exported: true, kind: partial, where I == Image<UInt8>)
    public func write<I>(_ image: I, time: CMTime) throws where I : ImageProtocol, I.Pixel == Pixel {
        precondition(image.width == width && image.height == height, "The size of the frame (\(image.width), \(image.height)) must be equal to (\(width), \(height)).")
        
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
        
        pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: time)
        
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
        
        assetWriterInput.markAsFinished()
        assetWriter.endSession(atSourceTime: lastTime!)
        assetWriter.finishWriting(completionHandler: completionHandler)
        
        finished = true
    }
}

public enum MovieWriterError : Error {
    case illegalStatus(status: AVAssetWriter.Status, error: Error)
    case failedToCreatePixelBuffer(CVReturn)
}

#endif
