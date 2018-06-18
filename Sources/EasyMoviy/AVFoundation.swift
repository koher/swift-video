#if canImport(AVFoundation) && !os(watchOS)
import EasyImagy
import AVFoundation

public protocol AVAssetPixel {
    static var opaqueZero: Self { get }
    static var recommendedFormat: OSType { get }
    static func convert(_ pixel: inout Self)
}

extension RGBA : AVAssetPixel where Channel == UInt8 {
    public static let opaqueZero: RGBA<UInt8> = RGBA(red: 0, green: 0, blue: 0)
    public static let recommendedFormat: OSType = kCVPixelFormatType_32BGRA
    public static func convert(_ pixel: inout RGBA<UInt8>) {
        swap(&pixel.red, &pixel.blue)
    }
}

extension PremultipliedRGBA : AVAssetPixel where Channel == UInt8 {
    public static let opaqueZero: PremultipliedRGBA<UInt8> = PremultipliedRGBA(red: 0, green: 0, blue: 0, alpha: 255)
    public static let recommendedFormat: OSType = kCVPixelFormatType_32BGRA
    public static func convert(_ pixel: inout PremultipliedRGBA<UInt8>) {
        swap(&pixel.red, &pixel.blue)
    }
}

extension UInt8 : AVAssetPixel {
    public static let opaqueZero: UInt8 = 0
    public static let recommendedFormat: OSType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    public static func convert(_ pixel: inout UInt8) {}
}

extension Movie where Pixel : AVAssetPixel {
    public init(avAsset: AVAsset) throws {
        let width: Int
        let height: Int
        do {
            let videoTracks = avAsset.tracks(withMediaType: .video)
            guard !videoTracks.isEmpty else { throw InitializationError.noVideoTrack }
            guard videoTracks.count == 1 else { throw InitializationError.multipleVideoTracks(videoTracks.count) }
            
            let videoTrack = videoTracks[0]
            
            let reader = try! AVAssetReader(asset: avAsset)
            reader.add(AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: Pixel.recommendedFormat]))
            let output = reader.outputs[0]
            output.alwaysCopiesSampleData = false
            reader.startReading()
            
            var firstPixelBuffer: CVPixelBuffer? = output.copyNextSampleBuffer().flatMap { buffer in CMSampleBufferGetImageBuffer(buffer) }
            guard let pixelBuffer = firstPixelBuffer else {
                self.init(width: 0, height: 0) { AnyIterator { nil } }
                return
            }
            
            width = CVPixelBufferGetWidth(pixelBuffer)
            height = CVPixelBufferGetHeight(pixelBuffer)

            reader.cancelReading()
        }
        
        let makeIterator: () -> AnyIterator<Image<Pixel>> = {
            let videoTracks = avAsset.tracks(withMediaType: .video)
            let videoTrack = videoTracks[0]
            let reader = try! AVAssetReader(asset: avAsset)
            do {
                let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: Pixel.recommendedFormat])
                output.alwaysCopiesSampleData = false
                reader.add(output)
            }
            reader.startReading()

            let count = width * height
            let byteLength = count * MemoryLayout<Pixel>.size
            let outBytesPerRow = width * MemoryLayout<Pixel>.size
            
            var frame = Image<Pixel>(width: width, height: height, pixel: Pixel.opaqueZero)
            
            return AnyIterator<Image<Pixel>> {
                let output = reader.outputs[0]
                
                guard
                    let buffer = output.copyNextSampleBuffer(),
                    let pixelBuffer = CMSampleBufferGetImageBuffer(buffer)
                    else {
                        return nil
                }

                if count > 0 { // To avoid `!` for empty images
                    let inBytesPerRow = Int(CVPixelBufferGetBytesPerRow(pixelBuffer))

                    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
                    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

                    // `!` because it never returns `nil` for the designated format
                    let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!
                    if inBytesPerRow == MemoryLayout<Pixel>.size * count {
                        let pointer = baseAddress.bindMemory(to: Pixel.self, capacity: count)
                        frame.withUnsafeMutableBufferPointer {
                            var pIn = pointer
                            var pOut = $0.baseAddress! // `!` becuase it never returns `nil` for non-empty buffers
                            for _ in 0..<count {
                                pOut.pointee = pIn.pointee
                                Pixel.convert(&pOut.pointee)
                                pIn += 1
                                pOut += 1
                            }
                        }
                    } else {
                        frame.withUnsafeMutableBufferPointer {
                            var rowHeadAddress = baseAddress
                            var pOut = $0.baseAddress! // `!` becuase it never returns `nil` for non-empty buffers
                            for _ in 0..<height {
                                var pIn = rowHeadAddress.bindMemory(to: Pixel.self, capacity: width)
                                for _ in 0..<width {
                                    pOut.pointee = pIn.pointee
                                    Pixel.convert(&pOut.pointee)
                                    pIn += 1
                                    pOut += 1
                                }
                                rowHeadAddress += inBytesPerRow
                            }
                        }
                    }
                }

                return frame
            }
        }
        
        self.init(width: width, height: height, makeIterator: makeIterator)
    }

    public init(contentsOf url: URL) throws {
        try self.init(avAsset: AVAsset(url: url))
    }

    public init(contentsOfFile path: String) throws {
        try self.init(contentsOf: URL(fileURLWithPath: path))
    }
}

extension Movie {
    public enum InitializationError: Error {
        case noVideoTrack
        case multipleVideoTracks(Int)
    }
}
#endif
