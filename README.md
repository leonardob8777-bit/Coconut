<div align="center">

<img src="docs/brand/coconut-icon.png" alt="Coconut app logo" width="112" height="112">

# Coconut

**A different view, every day.**

Animated wallpapers for iPhone · Created by [Leonardo](https://github.com/leonardob8777-bit)

**Compatibility: iOS 17.x · iOS 18.0 – 18.7.4 · iOS 26.0 – 26.1**

Automatic UUID only on iPhone 16 Pro (iOS 18.6.2). Other devices: enter the UUID manually or use TrollStore.

<a href="https://github.com/leonardob8777-bit/Coconut/releases/download/v0.6.23/Coconut-0.6.23-33-unsigned.ipa"><img src="docs/brand/download.svg?v=counts-2026-10-22T0650130729100000" alt="Download IPA — 4.12 MB · 1 downloads" width="244"></a><br>
<a href="https://github.com/leonardob8777-bit/Coconut/releases/tag/v0.6.23"><img src="docs/brand/notes.svg" alt="What’s new" width="120"></a>
<a href="https://github.com/leonardob8777-bit/Coconut/releases/download/v0.6.23/Coconut-0.6.23-source.zip"><img src="docs/brand/source.svg" alt="Source code" width="120"></a><br>
<a href="https://github.com/leonardob8777-bit/Coconut/stargazers"><img src="docs/brand/star.svg?v=counts-2026-10-22T0650130729100000" alt="Stars 1" width="120"></a>
<a href="https://github.com/leonardob8777-bit/Coconut/releases"><img src="docs/brand/releases.svg" alt="All releases" width="120"></a><br>
<a href="https://github.com/leonardob8777-bit/Coconut/issues/new?template=bug_report.yml"><img src="docs/brand/bug.svg" alt="Report bug" width="120"></a>
<a href="https://github.com/leonardob8777-bit/Coconut/issues/new?template=feature_request.yml"><img src="docs/brand/idea.svg" alt="Suggest idea" width="120"></a><br>

<sub>Counts checked October 22, 2026. Open links for current totals.<br>Use GitHub’s ☆ Star button to support Coconut.</sub>

</div>

---

## Your wallpaper, in motion

Explore the collection, watch a moving preview inside an iPhone frame, and keep your favorites close. Coconut downloads wallpapers when you need them, keeping the app small.

| Explore | Preview | Make it yours |
| :--- | :--- | :--- |
| **76 curated themes** in the current collection. Search, filter and save favorites. | **Motion previews**, a softly blurred backdrop and a decorative showcase that advances at the end of each video. | **Apply with your saved PosterBoard UUID.** Configure it once; reuse it for subsequent themes. |

## A lighter, smoother Coconut

**0.6.23 · build 33 · 4.12 MB · preview release**

- MP4 playback with local caching and preloading of the next showcase video.
- A refined scrolling header with a fixed iPhone preview, softer blur and a pinned collection title.
- Selected **HOT** themes and a creator card in Settings.
- English by default, with Spanish available in Settings.
- Wallpapers and videos stay online until requested; they are not packed into the IPA.

[Read the full release notes →](https://github.com/leonardob8777-bit/Coconut/releases/tag/v0.6.23)

## Install

1. **[Download Coconut.ipa](https://github.com/leonardob8777-bit/Coconut/releases/download/v0.6.23/Coconut-0.6.23-33-unsigned.ipa).**
2. Sign and install it using your preferred sideloading method.
3. Open Coconut and configure your PosterBoard UUID in Settings, if needed.
4. Pick a theme, watch its preview and tap **Apply**.

The main download is **unsigned**: it contains no personal provisioning profile or registered-device list. Sign it for your own device using a compatible sideloading method. Your signing method determines its validity period. Device and iOS compatibility still apply. Coconut is not distributed through the App Store.

<details>
<summary><strong>Compatibility and verification</strong></summary>

Compatibility: iOS 17.x · iOS 18.0 – 18.7.4 · iOS 26.0 – 26.1

Automatic UUID only on iPhone 16 Pro (iOS 18.6.2). Other devices: enter the UUID manually or use TrollStore.

This release does not expand engine compatibility. The exact public IPA was downloaded and its SHA-256 matched the local build. All 152 package/video links were accessible at publication. The 23 portable tests passed; 9 of 33 iOS experience tests still use expectations from the previous catalog and need updating. This build was not newly validated on a physical iPhone during the release review.

[Verification and checksums](https://github.com/leonardob8777-bit/Coconut/releases/tag/v0.6.23)

</details>



## Build the app

This repository contains the Coconut iOS application, its source code, releases and wallpaper catalog.

With Xcode and XcodeGen installed, run `xcodegen generate`, open `CoconutLab.xcodeproj`, choose your own signing team and build the `CoconutLab` scheme. Run `swift test` for the portable package tests.

## Catalog & credits

`catalog.json` supplies theme metadata, HTTPS download links and SHA-256 package digests. `scripts/add-theme.sh` adds a theme with its own release. Publish a revised package and its new digest together. Preview videos do not certify the final appearance on a physical iPhone.

Coconut's combined application is distributed under **AGPL-3.0**, with the original notices retained for its components. Thanks to **leminlimez / Pocket Poster**, **Eagle/Lara and their contributors**, and **Thomas Zoechling / ZIPFoundation**. Full attribution and licenses accompany the [source download](https://github.com/leonardob8777-bit/Coconut/releases/download/v0.6.23/Coconut-0.6.23-source.zip). Wallpaper artwork and the Coconut brand have separate terms; they are not automatically licensed as application code.

---

<div align="center">
<sub>Coconut · Created by Leonardo · A different view, every day.</sub>
</div>
