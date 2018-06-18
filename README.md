# EasyMoviy

```swift
import EasyMoviy
import EasyImagy

let movie = try! Movie<RGBA<UInt8>>(avAsset: asset)

// Obtains frames of the `movie`
for image in movie { // image: Image<RGBA<UInt8>>
    // Uses `image` here
}
```

## License

MIT
