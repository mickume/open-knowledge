# Local Mac DMG build - mirrors .github/workflows/desktop-build.yml
#
# Usage:
#   make               - unsigned DMG (no Apple certs required)
#   make dmg-signed    - signed + notarized DMG (requires env vars below)
#   make install       - install/refresh deps only
#   make clean         - remove electron-builder output
#
# Signed build env vars (export before running `make dmg-signed`):
#   CSC_LINK                    base64-encoded .p12  (base64 -i dev-id.p12 | pbcopy)
#   CSC_KEY_PASSWORD            .p12 export password
#   APPLE_ID                    Apple ID email
#   APPLE_APP_SPECIFIC_PASSWORD 16-char app-specific password from appleid.apple.com
#   APPLE_TEAM_ID               10-char Team ID from developer.apple.com/account
#   APPLE_API_KEY               (alt) path to .p8 key file
#   APPLE_API_KEY_ID            (alt) key ID
#   APPLE_API_ISSUER            (alt) issuer UUID (Team keys only)

DESKTOP := packages/desktop
OUT     := $(DESKTOP)/dist-desktop

.PHONY: all install build-workspace build-desktop prepare dmg dmg-signed clean

all: dmg

# Step 0 - install deps.
# ELECTRON_SKIP_REBUILD=0 overrides the default dev-mode skip in
# packages/desktop/scripts/postinstall.mjs so native modules are rebuilt
# against Electron's Node ABI (required for a packaged build).
install:
	ELECTRON_SKIP_REBUILD=0 pnpm install --frozen-lockfile

# Step 1 - workspace build.
# app must complete before cli so that packages/cli/dist/public/ exists when
# electron-builder copies it in via extraResources.
build-workspace:
	pnpm exec turbo run build --filter=@inkeep/open-knowledge-app
	pnpm exec turbo run build --filter=@inkeep/open-knowledge

# Step 2 - electron-vite bundles (main / preload / renderer).
build-desktop:
	cd $(DESKTOP) && pnpm run build:desktop

# Step 3 - prepare native prebuilds and stage @parcel/watcher.
prepare:
	cd $(DESKTOP) && node scripts/prepare-universal.mjs
	cd $(DESKTOP) && node scripts/stage-parcel-watcher.mjs

# Step 4a - package unsigned DMG (no Apple certs needed, runs locally after xattr -cr).
dmg: install build-workspace build-desktop prepare
	cd $(DESKTOP) && CSC_IDENTITY_AUTO_DISCOVERY=false \
		pnpm exec electron-builder --mac --publish never -c.mac.identity=null
	@echo ""
	@echo "DMG written to $(OUT)/"
	@echo "To run: xattr -cr $(OUT)/*.dmg then open it"

# Step 4b - package signed + notarized DMG (requires CSC_LINK and notary creds).
dmg-signed: install build-workspace build-desktop prepare
	cd $(DESKTOP) && pnpm exec electron-builder --mac --publish never
	@echo ""
	@echo "Signed DMG written to $(OUT)/"

clean:
	rm -rf $(OUT)
