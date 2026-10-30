<div align="center">

<img src="docs/brand/coconut-icon.png" alt="Coconut app logo" width="112" height="112">

# Coconut

**A different view, every day.**

Animated wallpapers for iPhone · Created by [Leonardo](https://github.com/leonardob8777-bit)

**Compatibility: iOS 17.x · iOS 18.0 – 18.7.4 · iOS 26.0 – 26.1**

Automatic PosterBoard UUID discovery follows the integrated engine's supported range. See [compatibility](#compatibility-and-verification).

<a href="https://github.com/leonardob8777-bit/Coconut/releases/download/v0.6.24/Coconut-0.6.24-34-unsigned.ipa"><img src="docs/brand/download.svg?v=counts-2026-10-30T124838Z" alt="Download Coconut IPA" width="244"></a><br>
<a href="https://github.com/leonardob8777-bit/Coconut/releases/tag/v0.6.24"><img src="docs/brand/notes.svg" alt="What’s new" width="120"></a>
<a href="https://github.com/leonardob8777-bit/Coconut/releases/download/v0.6.24/Coconut-0.6.24-source.zip"><img src="docs/brand/source.svg" alt="Source code" width="120"></a><br>
<a href="https://github.com/leonardob8777-bit/Coconut/stargazers"><img src="docs/brand/star.svg?v=counts-2026-10-30T124838Z" alt="Stars 4" width="120"></a>
<a href="https://github.com/leonardob8777-bit/Coconut/releases"><img src="docs/brand/releases.svg" alt="All releases" width="120"></a><br>
<a href="https://github.com/leonardob8777-bit/Coconut/issues/new?template=bug_report.yml"><img src="docs/brand/bug.svg" alt="Report bug" width="120"></a>
<a href="https://github.com/leonardob8777-bit/Coconut/issues/new?template=feature_request.yml"><img src="docs/brand/idea.svg" alt="Suggest idea" width="120"></a><br>

<sub>Counts checked October 30, 2026 (UTC). Open links for current totals.<br>Use GitHub’s ☆ Star button to support Coconut.</sub>

</div>

---

## Your wallpaper, in motion

Explore the collection, watch a moving preview inside an iPhone frame, and keep your favorites close. Coconut downloads wallpapers when you need them, keeping the app small.

| Explore | Preview | Make it yours |
| :--- | :--- | :--- |
| **76 offline themes** in this build, with new themes loaded from the online catalog. Search, filter and save favorites. | **Motion previews**, a softly blurred backdrop and a decorative showcase that advances at the end of each video. | **Apply with your saved PosterBoard UUID.** Configure it once; reuse it for subsequent themes. |

## A lighter, smoother Coconut

**0.6.24 · build 34 · preview release**

- MP4 playback with local caching and preloading of the next showcase video.
- A refined scrolling header with a fixed iPhone preview, softer blur and a pinned collection title.
- Selected **HOT** themes and a creator card in Settings.
- English by default, with Spanish available in Settings.
- Wallpapers and videos stay online until requested; they are not packed into the IPA.
- Automatic UUID discovery is no longer restricted to one iPhone 16 Pro/iOS build; the engine checks its own supported range before an attempt.

[Read the full release notes →](https://github.com/leonardob8777-bit/Coconut/releases/tag/v0.6.24)

## Install

1. **[Download Coconut.ipa](https://github.com/leonardob8777-bit/Coconut/releases/download/v0.6.24/Coconut-0.6.24-34-unsigned.ipa).**
2. Sign and install it using your preferred sideloading method.
3. Open Coconut and configure your PosterBoard UUID in Settings, if needed.
4. Pick a theme, watch its preview and tap **Apply**.

The main download is **unsigned**: it contains no personal provisioning profile or registered-device list. Sign it for your own device using a compatible sideloading method. Your signing method determines its validity period. Device and iOS compatibility still apply. Coconut is not distributed through the App Store.

<details>
<summary><strong>Compatibility and verification</strong></summary>

Compatibility: iOS 17.x · iOS 18.0 – 18.7.4 · iOS 26.0 – 26.1

Automatic UUID discovery: iOS 17.x, 18.0–18.7.1 and 26.0–26.0.1 on models supported by the integrated engine. The attempt runs once per app session; Coconut validates that the UUID belongs to PosterBoard before saving it. The engine excludes current MIE devices. On iOS 18.7.2–18.7.4 and 26.1, installation remains available with a UUID obtained separately or existing direct file access. See [Eagle's engine policy](https://github.com/leonardob8777-bit/Eagle/blob/main/lara/funcs/isunsupported.swift).

These are code-supported ranges, not a claim of physical validation on every device. The public IPA is unsigned so each user can sign it for their own device. Release-specific verification results are recorded in the release assets. The bundled fallback stays fixed for this build; new themes arrive through the online catalog without another IPA.

[Verification and checksums](https://github.com/leonardob8777-bit/Coconut/releases/tag/v0.6.24)

</details>



## Build the app

This repository contains the Coconut iOS application, its source code, releases and wallpaper catalog.

With Xcode and XcodeGen installed, run `xcodegen generate`, open `CoconutLab.xcodeproj`, choose your own signing team and build the `CoconutLab` scheme. Run `swift test` for the portable package tests.

## Catalog & credits

`catalog.json` supplies theme metadata, HTTPS download links and SHA-256 package digests. `scripts/add-theme.sh` adds a theme with its own release. Publish a revised package and its new digest together. Preview videos do not certify the final appearance on a physical iPhone.

Coconut's combined application is distributed under **AGPL-3.0**, with the original notices retained for its components. Thanks to **leminlimez / Pocket Poster**, **Eagle/Lara and their contributors**, and **Thomas Zoechling / ZIPFoundation**. Full attribution and licenses accompany the [source download](https://github.com/leonardob8777-bit/Coconut/releases/download/v0.6.24/Coconut-0.6.24-source.zip). Wallpaper artwork and the Coconut brand have separate terms; they are not automatically licensed as application code.

---

<div align="center">
<sub>Coconut · Created by Leonardo · A different view, every day.</sub>
</div>
