import EasyImagy

public struct Movie<Pixel> {
    public let width: Int
    public let height: Int
    
    private let _makeIterator: () -> (() -> Image<Pixel>?)
    
    public init(width: Int, height: Int, makeIterator: @escaping () -> (() -> Image<Pixel>?)) {
        self.width = width
        self.height = height
        self._makeIterator = makeIterator
    }
    
}

public struct MovieIterator<Pixel>: IteratorProtocol {
    private let width: Int
    private let height: Int
    
    private var iterator: () -> Image<Pixel>?
    
    internal init(width: Int, height: Int, iterator: @escaping () -> Image<Pixel>?) {
        self.width = width
        self.height = height
        self.iterator = iterator
    }
    
    public mutating func next() -> Image<Pixel>? {
        guard let frame = iterator() else { return nil }
        precondition(frame.width == width && frame.height == height, "Illegal frame size: frame.size = (\(frame.width), \(frame.height)), movie.size = (\(width), \(height)")
        return frame
    }
}

extension Movie: Sequence {
    public func makeIterator() -> MovieIterator<Pixel> {
        return MovieIterator(width: width, height: height, iterator: _makeIterator())
    }
}

