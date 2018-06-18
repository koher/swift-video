# EasyMoviy

```swift
import EasyMoviy
import EasyImagy

let movie = try! Movie<RGBA<UInt8>>(avAsset: asset)
for image in movie { // image: Image<RGBA<UInt8>>
    // Uses `image` here
}
```

## License

MIT
