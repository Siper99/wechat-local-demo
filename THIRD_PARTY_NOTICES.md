# Third-party references and resources

## SwiftUI-WeChat

- Source: https://github.com/wxxsw/SwiftUI-WeChat
- Author: Gesen (wxxsw).
- License: MIT, reproduced in `ThirdParty/SwiftUI-WeChat-LICENSE.txt`.
- Reused: the Root, Chat, Contact, Discover, Me and Shared image sets in `App/Assets.xcassets/WeChatReference/`.
- Referenced: `RootView`, `ChatView.Send`, `DiscoverRow`, `MeList` and the repository screenshots for navigation, grouping, input layout, and icon sizing. The implementation here targets iOS 17 and retains its own SwiftData storage and local editing features.

## WeChatSwift

- Source: https://github.com/alexiscn/WeChatSwift
- Author: alexiscn.
- License: MIT, reproduced in `ThirdParty/WeChatSwift-LICENSE.txt`.
- Referenced: `SessionCellNode` (48 pt avatars, 72 pt rows, 16 pt leading inset), `ChatInputPanelNode`, and `DiscoverViewController`. No Texture, database, or networking dependencies were imported.

The upstream WeChatSwift README separately attributes WeChat artwork and product design to WeChat/Tencent and says not to use those resources in commercial applications. Repository code licenses do not grant ownership of those third-party trademarks or artwork. This repository remains a local simulation prototype, not an official WeChat client.
