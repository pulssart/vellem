# Releasing Vellem

End-to-end pipeline to ship a signed + notarized DMG that opens without Gatekeeper friction.

## One-time setup

### 1. Developer ID Application certificate

You need an active **Apple Developer Program** membership ($99/year). Team ID: `MKAFV9VL9V`.

1. Open **Xcode → Settings → Accounts**.
2. Select your Apple ID, then click **Manage Certificates…**.
3. Click **+** → **Developer ID Application**.
4. Verify in Terminal:
   ```bash
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```
   You should see `Developer ID Application: Adrien DONOT (MKAFV9VL9V)`.

### 2. App-specific password for notarization

1. Sign in at <https://appleid.apple.com/>.
2. Go to **Sign-In and Security → App-Specific Passwords**.
3. Click **+**, label it `Vellem notarization`, copy the generated password (format `xxxx-xxxx-xxxx-xxxx`).

### 3. Store notary credentials in Keychain

```bash
xcrun notarytool store-credentials vellem-notary \
  --apple-id "your.apple.id@example.com" \
  --team-id MKAFV9VL9V \
  --password "xxxx-xxxx-xxxx-xxxx"
```

You only do this once. The password lives in your login Keychain.

## Cutting a release

```bash
# Bump version in Vellem/Info.plist (CFBundleShortVersionString), then:
./script/release.sh
```

The script:

1. Verifies signing identity + notary profile exist.
2. Builds Release with **manual signing** using `Developer ID Application`.
3. Re-signs the embedded `vellem-mcp` binary with hardened runtime + timestamp.
4. Re-signs the outer `.app` bundle.
5. Stages the app + an `Applications` symlink and packages a `.dmg`.
6. Signs the `.dmg`.
7. Submits to Apple notary service and **waits** for the verdict.
8. **Staples** the notarization ticket so the DMG opens offline.
9. Prints the SHA-256 and a ready-to-run `gh release create` command.

Output: `dist/Vellem-<version>.dmg`

## Publishing to GitHub

```bash
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Vellem/Info.plist)
gh release create "v${VERSION}" "dist/Vellem-${VERSION}.dmg" \
  --title "Vellem ${VERSION}" \
  --notes "See CHANGELOG.md"
```

The landing page at <https://pulssart.github.io/vellem/> reads `releases/latest` from the GitHub API and automatically wires up the **Download for macOS** button to the new DMG. No manual update needed.

## Troubleshooting

- **`notarytool` says `Invalid`**: download the log with `xcrun notarytool log <submission-id> --keychain-profile vellem-notary`. Common culprits: missing hardened runtime, missing timestamp, embedded binary not signed with Developer ID.
- **Gatekeeper still complains on a fresh Mac**: confirm with `spctl --assess --type execute --verbose dist/Vellem-*.dmg` — should say `accepted`. If not, the DMG was modified after stapling.
- **DMG can be opened but app inside cannot**: the inner `.app` was not properly re-signed. The release script re-signs both the embedded MCP and the outer bundle precisely to avoid this.
