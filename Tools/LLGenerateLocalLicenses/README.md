# LicenseList — Integrating Local Swift Packages
Automatically collect **LICENSE** files from local SwiftPM packages and merge them into `LicenseListView` at build‑time.

---

## 1. Why is this necessary?

SwiftPM does **not copy** packages you add with `.package(path: …)` or **Add Local Package…**.  
Their license files never reach:

```
DerivedData/<App>/SourcePackages/checkouts/…
```

where the standard **LicenseList** plug‑in searches.

To bridge the gap we:

1. **Scan the workspace** for local packages.  
2. **Dump their licenses** to a JSON file inside the sandbox.  
3. Let **SourcePackagesParser** read that JSON and merge the entries.

Everything happens automatically during a normal Xcode build.

---

## 2. Components shipped with LicenseList

| Target | Type | Purpose |
|--------|------|---------|
| `LicenseList` | Library | Runtime UI (`LicenseListView`) |
| `LicenseListPlugin` | Build‑Tool Plug‑in | Extract licenses from remote / registry packages |
| `LLGenerateLocalLicenses` | **Executable** | *New* — CLI that scans the workspace and writes `local-licenses.json` |

`LLGenerateLocalLicenses` is built and run **only** from your app’s build script; it is *not* included in the final app.

---

## 3. Add the Run Script phase to your app target

1. **Xcode** → *Target* ▸ **Build Phases** ▸ ➕ **New Run Script Phase**  
2. Drag the phase **above “Compile Sources”** so it executes *before* the LicenseList plug‑in.  
3. Paste the script below (bash):

```bash
# === Generate licenses for local SwiftPM packages =========================

set -euo pipefail
echo "🏗  LicenseList: collecting local package licenses…"

## 1) Paths -----------------------------------------------------------------
DERIVED_DATA="${BUILD_DIR%/Build/*}"
SOURCE_PKGS="${DERIVED_DATA}/SourcePackages"
LICENSELIST_PATH="${SOURCE_PKGS}/checkouts/LicenseList"

## 2) Build LLGenerateLocalLicenses in a *separate* folder to avoid DB locks
CLI_BUILD_DIR="${DERIVED_DATA}/_LLCLI_Build"
mkdir -p "$CLI_BUILD_DIR"

swift build \
  --package-path "$LICENSELIST_PATH" \
  --build-path   "$CLI_BUILD_DIR" \
  -c release \
  --product LLGenerateLocalLicenses

CLI_BIN="$CLI_BUILD_DIR/release/LLGenerateLocalLicenses"
EXTRA_JSON="$SOURCE_PKGS/local-licenses.json"

## 3) Run the CLI -----------------------------------------------------------
"$CLI_BIN" \
  --workspace "$SRCROOT" \
  --output    "$EXTRA_JSON"

echo "✅  LicenseList: wrote $EXTRA_JSON"
```

> **Why use `--build-path`?**  
> Xcode already holds a write‑lock on  
> `…/SourcePackages/checkouts/LicenseList/.build/build.db`.  
> Building the CLI elsewhere prevents the *readonly database* error.

---

## 4. Build‑time flow

```text
Pre‑build Run Script (your app) ──┐
  1. scan workspace               │
  2. build & run CLI              │
                                  ▼
                          local‑licenses.json
                                  ▼
LicenseListPlugin ───────────> reads workspace‑state.json  
                               + local‑licenses.json  
                                  ▼
                            LicenseList.swift
                                  ▼
                         LicenseListView at runtime
```

---

## 5. Verify the setup

Build once. In the Xcode log you should see:

```text
🏗  LicenseList: collecting local package licenses…
✅  LicenseList: wrote /…/SourcePackages/local-licenses.json
```

Launch the app — local packages now appear in **LicenseListView**.

---
