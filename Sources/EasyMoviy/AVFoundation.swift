#if os(iOS) || os(macOS) || os(watchOS) || os(tvOS)
import EasyImagy
import AVFoundation

// TODO: integrate these using conditional conformance in Swift 4.1 or later

extension Movie where Pixel == RGBA<UInt8> {
    #if os(iOS) || os(watchOS) || os(tvOS)
    private static let recommendedFormat: OSType = kCVPixelFormatType_32BGRA
    private static func convert(_ pixel: inout RGBA<UInt8>) {
        swap(&pixel.red, &pixel.blue)
    }
    #endif
    #if os(macOS)
    private static let recommendedFormat: OSType = kCVPixelFormatType_32ARGB
    private static func convert(_ pixel: inout RGBA<UInt8>) {
        let alpha = pixel.red
        let p = UnsafeMutablePointer<RGBA<UInt8>>(&pixel)
        p.withMemoryRebound(to: UInt32.self, capacity: 1) {
            $0.pointee <<= 8
        }
        pixel.alpha = alpha
    }
    #endif

    public init(avAsset: AVAsset) throws {
        let videoTracks = avAsset.tracks(withMediaType: .video)
        guard !videoTracks.isEmpty else { throw InitializationError.noVideoTrack }
        guard videoTracks.count == 1 else { throw InitializationError.multipleVideoTracks(videoTracks.count) }

        let videoTrack = videoTracks[0]
        let size = videoTrack.naturalSize
        let width = Int(size.width)
        let height = Int(size.height)
        let count = width * height
        let byteLength = count * MemoryLayout<Pixel>.size

        let makeIterator: () -> AnyIterator<Image<Pixel>> = {
            var frame = Image<Pixel>(width: width, height: height, pixel: RGBA(0x000000ff))
            
            let reader = try! AVAssetReader(asset: avAsset)
            reader.add(AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: Movie.recommendedFormat]))
            reader.startReading()
            
            return AnyIterator<Image<Pixel>> {
                let output = reader.outputs[0]
                output.alwaysCopiesSampleData = false
                guard
                    let buffer = output.copyNextSampleBuffer(),
                    let pixelBuffer = CMSampleBufferGetImageBuffer(buffer)
                else {
                    return nil
                }

                if count > 0 { // To avoid `!` for empty images
                    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
                    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

                    // `!` because it never returns `nil` for the designated format
                    let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!
                    let pointer = baseAddress.bindMemory(to: Pixel.self, capacity: count)
                    frame.withUnsafeMutableBufferPointer {
                        var pIn = pointer
                        var pOut = $0.baseAddress! // `!` becuase it never returns `nil` for non-empty buffers
                        for _ in 0..<count {
                            pOut.pointee = pIn.pointee
                            Movie.convert(&pOut.pointee)
                            pIn += 1
                            pOut += 1
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

extension Movie where Pixel == UInt8 {
    private static let recommendedFormat: OSType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    
    public init(avAsset: AVAsset) throws {
        let videoTracks = avAsset.tracks(withMediaType: .video)
        guard !videoTracks.isEmpty else { throw InitializationError.noVideoTrack }
        guard videoTracks.count == 1 else { throw InitializationError.multipleVideoTracks(videoTracks.count) }
        
        let videoTrack = videoTracks[0]
        let size = videoTrack.naturalSize
        let width = Int(size.width)
        let height = Int(size.height)
        let count = width * height
        let byteLength = count * MemoryLayout<Pixel>.size
        
        let makeIterator: () -> AnyIterator<Image<Pixel>> = {
            var frame = Image<Pixel>(width: width, height: height, pixel: 0x00)
            
            let reader = try! AVAssetReader(asset: avAsset)
            reader.add(AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: Movie.recommendedFormat]))
            reader.startReading()
            
            return AnyIterator<Image<Pixel>> {
                let output = reader.outputs[0]
                output.alwaysCopiesSampleData = false
                guard
                    let buffer = output.copyNextSampleBuffer(),
                    let pixelBuffer = CMSampleBufferGetImageBuffer(buffer)
                    else {
                        return nil
                }
                
                if count > 0 { // To avoid `!` for empty images
                    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
                    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
                    
                    // `!` because it never returns `nil` for the designated format
                    let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)!
                    let pointer = UnsafeRawBufferPointer.init(start: baseAddress, count: byteLength)
                    frame.withUnsafeMutableBytes {
                        $0.copyBytes(from: pointer)
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
