# AquaTimer contributor instructions

AquaTimer is a Swift and AppKit countdown timer for macOS 14 and later. Its visual design draws on Mac OS X Tiger, with brushed metal in the timer window, pinstripes in Settings, and an LCD inspired by a physical timer. Use AppKit directly for windows, menus, and controls. Keep countdown logic separate from drawing code.

## Design references

- Use Apple's Tiger-era HIG for Aqua materials, window chrome, controls, and layout. [Apple Human Interface Guidelines, December 6, 2005 (PDF mirror)](https://blog-geofcrowl-static-images.s3.us-east-1.amazonaws.com/2020-02-17-collection-higs/APPLE-Guidelines-2005.pdf)
- Use the current macOS HIG for interaction conventions, keyboard navigation, and accessibility. Preserve these behaviors when drawing custom controls. [Apple HIG — Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos)
- Make original assets for AquaTimer and reuse the shared drawing code in `AquaTimer/Aqua/` where it fits. When a design review calls for an SVG preview, show the control at its intended size as well as enlarged before integrating it.

## What belongs in Git

- Keep app source, Xcode project files, build scripts, app resources, license notices, and this `AGENTS.md` in the repository.
- Keep original design drafts and their corresponding PNG previews together under `design/window/`, `design/controls/`, `design/display/`, `design/settings/`, or `design/icon/`. Keep paths in asset generation scripts in sync when moving source artwork.
- Keep internal engineering documents, implementation plans, research notes, review reports, and other temporary working files local. Do not commit them in a `docs/` directory or elsewhere, including inside archives. Add public documentation only when explicitly requested.
- Store third-party reference screenshots, downloaded HIG PDFs, pixel comparison images containing reference material, build logs, and scratch exports under the ignored `.build/` directory or outside the repository. Keep Xcode user state and build outputs out of Git. Review `git status --short` and `git diff --cached --name-only` before committing.

## Build and verify

- Open `AquaTimer.xcodeproj` and use the `AquaTimer` scheme. If the project structure changes, update `project.yml` and regenerate the checked-in project with `./script/generate_project.sh`.
- Use `./script/build_and_run.sh` to build and launch the current checkout. Use `./script/test.sh` for relevant XCTest checks. Match verification to the change and follow any task-specific limits on tests or app launches.
