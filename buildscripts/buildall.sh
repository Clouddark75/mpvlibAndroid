name: release

on:
  push:
    tags:
      - '*'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    permissions:
      contents: write

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: temurin

      - name: Export env vars
        run: buildscripts/include/ci.sh export >> $GITHUB_ENV

      - name: Install deps
        run: |
          sudo apt-get update
          sudo apt-get install -y autoconf pkg-config libtool ninja-build python3-pip
          pip3 install --user meson

      # 🔥 FIX PRINCIPAL: permisos de scripts
      - name: Fix script permissions
        run: |
          find buildscripts -type f -name "*.sh" -exec chmod +x {} \;

      - name: Build the release artifacts
        run: |
          set -eux
          unset ANDROID_SDK_ROOT
          cd buildscripts
          ./download.sh > /dev/null

          ./buildall.sh --arch x86 mpv
          ./buildall.sh --arch x86_64 mpv
          ./buildall.sh --arch arm64 mpv
          ./buildall.sh
        env:
          GRADLE_OPTS: -Xmx4G

      - name: Get tag name
        if: startsWith(github.ref, 'refs/tags/')
        run: |
          echo "VERSION_TAG=${GITHUB_REF#refs/tags/}" >> $GITHUB_ENV

      - name: Copy build artifacts
        if: startsWith(github.ref, 'refs/tags/')
        run: |
          set -e
          mv app/build/outputs/aar/app-release.aar mpv-android-lib-${{ env.VERSION_TAG }}.aar

      - name: Create Release
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ env.VERSION_TAG }}
          name: mpv-android-lib ${{ env.VERSION_TAG }}
          body: |
            library version ${{ env.VERSION_TAG }}
          files: |
            mpv-android-lib-${{ env.VERSION_TAG }}.aar
          draft: true
          prerelease: false
