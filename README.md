# SwiftVideo

```swift
import SwiftVideo
import SwiftImage

let video = try! Video<RGBA<UInt8>>(avAsset: asset)

// Obtains frames of the `video`
for image in video { // image: Image<RGBA<UInt8>>
    // Uses `image` here
}
```

## License

MIT
