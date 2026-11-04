#!/bin/sh
# Xcode Cloud runs this right after cloning the repo, before it builds or tests anything.
set -eu

# Work from the repo root, where project.yml is.
cd "$CI_PRIMARY_REPOSITORY_PATH"

# iRead.xcodeproj is generated from project.yml and isn't committed (only its Package.resolved is), so make it here.
brew install xcodegen
xcodegen generate

# SwiftLint runs as a package build-tool plugin. On a laptop Xcode asks once to "Trust & Enable" it;
# nobody can click that on CI, so skip the check. (The first key really is spelled "Validatation".)
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

# Packages are NOT resolved here: Apple doesn't support forcing resolution on Xcode Cloud.
# It builds the exact versions in the committed iRead.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved.
