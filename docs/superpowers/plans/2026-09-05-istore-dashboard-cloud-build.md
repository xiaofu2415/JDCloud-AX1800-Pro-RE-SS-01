# iStoreOS Dashboard Cloud Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the verified Argon firmware as the stable RE-SS-01 variant, add a separately versioned iStoreOS Dashboard beta with QuickStart, iStore and a LuCI terminal, rename the GitHub repository, and complete a successful GitHub Actions build and prerelease.

**Architecture:** Keep one builder repository and one workflow with a required `variant` input. Both variants share the LibWrt `25.12-nss` source, RE-SS-01 target, factory alignment, common packages and safe first-boot defaults. Variant metadata, required packages and release preparation live in testable shell scripts; `argon` and `istore` have separate config and version files. The iStore work is developed in a temporary `feature/istoreos-quickstart` worktree and remains unmerged until physical-router validation passes.

**Tech Stack:** Git, GitHub Actions, Bash, Ruby YAML contract tests, LibWrt/OpenWrt build system, LuCI, LinkEase iStore/QuickStart feeds, GitHub Releases.

**Spec:** `docs/superpowers/specs/2026-09-05-dual-firmware-release-design.md`

## Global Constraints

- Only build for `CONFIG_TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y`.
- Keep `LiBwrt/LibWrt` and branch `25.12-nss`; do not switch the base firmware to iStoreOS.
- Preserve the already flashed Argon firmware and migration-era Release `re-ss-01-4-1`.
- Do not flash the router, change its LAN address, mount `storage`, enable swap, or change live-router settings during this plan.
- The iStore variant keeps Argon for ordinary LuCI pages and Bootstrap for recovery, but QuickStart is its landing page; there is no separate Argon homepage entry.
- PassWall2, MosDNS, AdGuard Home, Docker, Tailscale and SQM remain disabled on first boot; nlbwmon remains enabled with three database generations.
- `luci-app-ttyd` must not add a WAN firewall opening. LAN-only access is proved during later physical acceptance.
- The iStore Release is always a prerelease and never GitHub Latest.
- Every behavioral change starts with a failing repository test and ends with a focused commit.
- Do not merge `feature/istoreos-quickstart` into `main` until the user flashes the beta and the physical acceptance checklist passes.

---

## Task 1: Publish the approved design and implementation plan

**Files:**

- Verify: `docs/superpowers/specs/2026-09-05-dual-firmware-release-design.md`
- Verify: `docs/superpowers/plans/2026-09-05-istore-dashboard-cloud-build.md`
- Verify: `.gitignore`

- [ ] **Step 1: Run the unchanged baseline contract test**

Run:

```bash
bash tests/test-builder.sh
```

Expected: all current Argon-only checks pass, ending with `requested packages and defaults: ok`.

- [ ] **Step 2: Confirm the planning commits are isolated from firmware implementation**

Run:

```bash
git status --short --branch
git log --oneline --decorate -4
```

Expected: `main` is ahead of `origin/main`; only this plan is uncommitted, and the two existing design commits are visible.

- [ ] **Step 3: Commit this plan**

Run:

```bash
git add docs/superpowers/plans/2026-09-05-istore-dashboard-cloud-build.md
git commit -m "Plan iStore dashboard cloud build"
```

Expected: one documentation-only commit on `main`.

- [ ] **Step 4: Push the three approved planning commits before repository mutation**

Run:

```bash
git push origin main
git status --short --branch
```

Expected: `main...origin/main` with no ahead/behind marker and a clean worktree. If Git credentials fail, use the already authenticated GitHub browser to restore repository authorization, then retry the same push; do not rewrite commits.

---

## Task 2: Rename and verify the GitHub repository

**External state:**

- Rename: `xiaofu2415/OpenWrt360_6.1`
- To: `xiaofu2415/JDCloud-AX1800-Pro-RE-SS-01`
- Modify local remote: `origin`

- [ ] **Step 1: Record the pre-rename GitHub state**

In the authenticated GitHub browser, verify that the repository owner is `xiaofu2415`, the default branch is `main`, and Release `re-ss-01-4-1` is present.

Expected: all three facts are visible before the rename.

- [ ] **Step 2: Rename through GitHub Settings**

Open **Settings → General → Repository name**, set the exact slug to:

```text
JDCloud-AX1800-Pro-RE-SS-01
```

Expected: GitHub redirects to `https://github.com/xiaofu2415/JDCloud-AX1800-Pro-RE-SS-01`.

- [ ] **Step 3: Update the local remote and verify the migration**

Run:

```bash
git remote set-url origin https://github.com/xiaofu2415/JDCloud-AX1800-Pro-RE-SS-01.git
git remote -v
git ls-remote --symref origin HEAD
```

Expected: fetch and push URLs use the new slug; remote `HEAD` resolves to `refs/heads/main`.

- [ ] **Step 4: Verify releases survived the rename**

Open:

```text
https://github.com/xiaofu2415/JDCloud-AX1800-Pro-RE-SS-01/releases/tag/re-ss-01-4-1
```

Expected: the migration-era recovery Release and its assets remain available. Do not delete, edit or relabel it.

---

## Task 3: Create an isolated iStore feature worktree

**Files:**

- Use: `.gitignore`
- Create worktree directory: `.worktrees/feature-istoreos-quickstart`
- Create branch: `feature/istoreos-quickstart`

- [ ] **Step 1: Prove the worktree container is ignored**

Run:

```bash
git check-ignore -q .worktrees
```

Expected: exit status `0`.

- [ ] **Step 2: Create the branch in an isolated worktree**

Run:

```bash
git worktree add .worktrees/feature-istoreos-quickstart -b feature/istoreos-quickstart
git worktree list
```

Expected: `main` remains in the original checkout and `feature/istoreos-quickstart` appears at `.worktrees/feature-istoreos-quickstart`.

- [ ] **Step 3: Establish a clean feature baseline**

Run from `.worktrees/feature-istoreos-quickstart`:

```bash
bash tests/test-builder.sh
git status --short --branch
```

Expected: baseline checks pass and the feature worktree is clean.

All remaining implementation tasks run from this feature worktree unless a step explicitly says otherwise.

---

## Task 4: Split configuration and version metadata into two variants

**Files:**

- Modify: `tests/test-builder.sh`
- Rename: `configs/jdcloud-re-ss-01.config` → `configs/re-ss-01-argon.config`
- Create: `configs/re-ss-01-istore.config`
- Create: `versions/argon.version`
- Create: `versions/istore.version`
- Create: `.github/scripts/variant-metadata.sh`

- [ ] **Step 1: Add failing contract assertions for the two configurations**

Change `tests/test-builder.sh` so it requires:

```ruby
variants = {
  "argon" => {
    "config" => "configs/re-ss-01-argon.config",
    "version" => "1.0.0",
    "tag" => "re-ss-01-argon-v1.0.0",
    "prerelease" => "false"
  },
  "istore" => {
    "config" => "configs/re-ss-01-istore.config",
    "version" => "0.1.0-beta.1",
    "tag" => "re-ss-01-istore-v0.1.0-beta.1",
    "prerelease" => "true"
  }
}
```

For each variant, invoke `.github/scripts/variant-metadata.sh`, parse its `key=value` output, and assert exact `config_file`, `version`, `tag`, `artifact_name`, `release_title` and `prerelease` values. Assert both configs select only RE-SS-01 and contain all common package entries.

- [ ] **Step 2: Run the test to prove the new contract is absent**

Run:

```bash
bash tests/test-builder.sh
```

Expected failure: missing `configs/re-ss-01-argon.config`, `versions/argon.version`, or `.github/scripts/variant-metadata.sh`.

- [ ] **Step 3: Create the split configs and version files**

Move the existing config to `configs/re-ss-01-argon.config`. Copy it to `configs/re-ss-01-istore.config`, then add only these iStore-specific explicit selections:

```text
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-app-store=y
CONFIG_PACKAGE_quickstart=y
CONFIG_PACKAGE_luci-app-quickstart=y
```

Create exact version file contents:

```text
versions/argon.version: 1.0.0
versions/istore.version: 0.1.0-beta.1
```

- [ ] **Step 4: Implement deterministic variant metadata**

Create `.github/scripts/variant-metadata.sh` with these rules:

- accept exactly one argument, `argon` or `istore`;
- reject any other value with exit status `2`;
- read the matching `versions/<variant>.version` relative to the repository root;
- reject whitespace, empty versions and versions that do not match `^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$`;
- emit exact GitHub-output-safe lines for `variant`, `config_file`, `version`, `tag`, `artifact_name`, `release_title` and `prerelease`;
- use `京东云 AX1800 PRO（RE-SS-01）· Argon v<version>` and `京东云 AX1800 PRO（RE-SS-01）· iStoreOS Dashboard v<version>` as titles.

- [ ] **Step 5: Run focused tests**

Run:

```bash
bash -n .github/scripts/variant-metadata.sh
bash tests/test-builder.sh
```

Expected: metadata tests and the unchanged factory/default tests pass.

- [ ] **Step 6: Commit the variant model**

Run:

```bash
git add tests/test-builder.sh configs versions .github/scripts/variant-metadata.sh
git commit -m "Add Argon and iStore firmware variants"
```

---

## Task 5: Add isolated iStore and QuickStart feeds

**Files:**

- Modify: `tests/test-builder.sh`
- Modify: `.github/scripts/add-package-feeds.sh`

Use these verified upstream feed branches:

```text
src-git istore https://github.com/linkease/istore.git;main
src-git nas https://github.com/linkease/nas-packages.git;master
src-git nas_luci https://github.com/linkease/nas-packages-luci.git;main
```

- [ ] **Step 1: Add failing feed-isolation tests**

In `tests/test-builder.sh`, create temporary feed files and run:

```bash
bash .github/scripts/add-package-feeds.sh "$argon_feeds" argon
bash .github/scripts/add-package-feeds.sh "$istore_feeds" istore
```

Assert:

- both files contain PassWall packages, PassWall2 and MosDNS exactly once;
- the Argon file contains none of `istore`, `nas`, `nas_luci`;
- the iStore file contains the three exact lines above exactly once and in `istore`, `nas`, `nas_luci` order;
- running the script twice is idempotent;
- an unknown variant fails.

- [ ] **Step 2: Prove current behavior fails the new contract**

Run:

```bash
bash tests/test-builder.sh
```

Expected failure: the current feed script has no variant argument and does not add iStore feeds.

- [ ] **Step 3: Implement variant-aware feed addition**

Update `.github/scripts/add-package-feeds.sh` to accept `FEEDS_CONF VARIANT`, keep the three common feeds unchanged, add the LinkEase feeds only for `istore`, and reject unknown variants before modifying the file.

- [ ] **Step 4: Verify and commit**

Run:

```bash
bash -n .github/scripts/add-package-feeds.sh
bash tests/test-builder.sh
git add .github/scripts/add-package-feeds.sh tests/test-builder.sh
git commit -m "Add isolated iStore and QuickStart feeds"
```

Expected: all local tests pass before the commit.

---

## Task 6: Centralize and test required-package policy

**Files:**

- Create: `.github/scripts/required-packages.sh`
- Modify: `tests/test-builder.sh`
- Modify: `configs/re-ss-01-argon.config`
- Modify: `configs/re-ss-01-istore.config`

- [ ] **Step 1: Add a failing package-policy test**

Require `.github/scripts/required-packages.sh argon` to emit exactly the common runtime packages:

```text
luci-app-passwall2
luci-app-mosdns
luci-app-adguardhome
luci-app-nlbwmon
luci-app-dockerman
tailscale
luci-app-sqm
sqm-scripts-nss
luci-theme-argon
luci-theme-bootstrap
luci-i18n-base-zh-cn
```

Require the `istore` invocation to emit the same list followed by:

```text
luci-app-ttyd
luci-app-store
quickstart
luci-app-quickstart
```

Reject duplicates, blank lines and unknown variants. For each emitted package, assert the matching `CONFIG_PACKAGE_<name>=y` line is present in that variant config.

- [ ] **Step 2: Run the test and observe the missing helper**

Run:

```bash
bash tests/test-builder.sh
```

Expected failure: `.github/scripts/required-packages.sh` is missing.

- [ ] **Step 3: Implement the package policy and satisfy config checks**

Create the helper with exact deterministic output. Add `CONFIG_PACKAGE_luci-i18n-base-zh-cn=y` to both configs if `make defconfig` does not already materialize it from `CONFIG_LUCI_LANG_zh_Hans=y`; keep the explicit language selector in both configs.

- [ ] **Step 4: Verify and commit**

Run:

```bash
bash -n .github/scripts/required-packages.sh
bash tests/test-builder.sh
git add .github/scripts/required-packages.sh tests/test-builder.sh configs
git commit -m "Define packages required by each firmware variant"
```

---

## Task 7: Make first-boot policy variant-aware without opening ttyd to WAN

**Files:**

- Modify: `tests/test-builder.sh`
- Rename: `files/etc/uci-defaults/zz-re-ss-01-services` → `files/etc/uci-defaults/99-re-ss-01-services`

- [ ] **Step 1: Add failing first-boot policy assertions**

Update tests to require the final first-boot script to:

- disable `passwall2 mosdns adguardhome dockerd tailscale sqm`;
- keep nlbwmon history at three generations;
- set Argon as `luci.main.mediaurlbase` for both variants;
- contain no `uci set network`, no LAN IP assignment, no `swapon`, no mount command and no `firewall` rule for port `7681`;
- preserve QuickStart's own menu priority instead of adding a competing custom homepage redirect;
- run after upstream QuickStart's `50_luci-quickstart`, which is why the local file is named `99-re-ss-01-services`.

- [ ] **Step 2: Run the test and confirm the filename contract fails**

Run:

```bash
bash tests/test-builder.sh
```

Expected failure: `files/etc/uci-defaults/99-re-ss-01-services` is absent.

- [ ] **Step 3: Rename the defaults script and keep behavior minimal**

Rename the file without adding a QuickStart redirect or a ttyd firewall rule. Update comments to explain:

- QuickStart remains the first LuCI menu entry in the iStore package and therefore the landing page;
- Argon is still the rendering theme for all LuCI pages;
- ttyd is reachable only through the existing LAN-side LuCI/firewall policy and receives no WAN accept rule.

- [ ] **Step 4: Verify and commit**

Run:

```bash
sh -n files/etc/uci-defaults/99-re-ss-01-services
bash tests/test-builder.sh
git add files/etc/uci-defaults tests/test-builder.sh
git commit -m "Preserve safe defaults for both firmware variants"
```

---

## Task 8: Add deterministic release collection and verification

**Files:**

- Create: `.github/scripts/prepare-release.sh`
- Create: `.github/scripts/verify-release.sh`
- Create: `tests/fixtures/release/`
- Modify: `tests/test-builder.sh`

- [ ] **Step 1: Build a failing release fixture test**

Create a temporary target directory containing:

```text
libwrt-qualcommax-ipq60xx-jdcloud_re-ss-01-squashfs-factory.bin
libwrt-qualcommax-ipq60xx-jdcloud_re-ss-01-squashfs-sysupgrade.bin
libwrt-qualcommax-ipq60xx-jdcloud_re-ss-01-initramfs-uImage.itb
libwrt-qualcommax-ipq60xx-jdcloud_re-ss-01.manifest
profiles.json
config.buildinfo
```

Make the factory fixture exactly 65536 bytes. Put every package from `required-packages.sh istore` in the manifest. Invoke:

```bash
bash .github/scripts/prepare-release.sh "$target_dir" "$output_dir" istore 0.1.0-beta.1 source-sha builder-sha configs/re-ss-01-istore.config
bash .github/scripts/verify-release.sh "$output_dir" istore 0.1.0-beta.1
```

Assert the output has exactly one renamed factory, sysupgrade and initramfs file, the renamed manifest, `profiles.json`, `build.config`, `BUILD-METADATA.txt` and `SHA256SUMS`. Assert metadata records source commit, builder commit, config path, variant and version.

Add negative cases for:

- unaligned factory image;
- missing sysupgrade, initramfs or manifest;
- manifest missing `luci-app-quickstart`;
- checksum mismatch.

- [ ] **Step 2: Run the test and observe missing release helpers**

Run:

```bash
bash tests/test-builder.sh
```

Expected failure: `.github/scripts/prepare-release.sh` is missing.

- [ ] **Step 3: Implement release preparation**

`prepare-release.sh` must:

- accept exactly seven positional arguments shown above;
- validate variant/version through `variant-metadata.sh` and reject mismatches;
- select files containing `jdcloud_re-ss-01` only;
- fail on zero or multiple matches for factory, sysupgrade, initramfs or manifest;
- copy and rename assets with prefix `jdcloud-re-ss-01-libwrt-<variant>-v<version>`;
- copy the selected config as `build.config`;
- write `BUILD-METADATA.txt` with one `key=value` record per line;
- generate `SHA256SUMS` last and exclude the checksum file itself.

- [ ] **Step 4: Implement release verification**

`verify-release.sh` must:

- validate all required files are non-empty;
- verify `SHA256SUMS` from inside the output directory;
- verify factory byte count modulo `65536` equals `0`;
- call `required-packages.sh` and match each package in the manifest as a complete first field;
- reject any firmware filename for another device or variant.

- [ ] **Step 5: Verify and commit**

Run:

```bash
bash -n .github/scripts/prepare-release.sh
bash -n .github/scripts/verify-release.sh
bash tests/test-builder.sh
git add .github/scripts/prepare-release.sh .github/scripts/verify-release.sh tests
git commit -m "Validate and name RE-SS-01 release assets"
```

---

## Task 9: Convert GitHub Actions to a dual-variant workflow

**Files:**

- Modify: `.github/workflows/build-re-ss-01.yml`
- Modify: `tests/test-builder.sh`

- [ ] **Step 1: Add failing workflow contract tests**

Require the parsed workflow to have:

```yaml
workflow_dispatch:
  inputs:
    variant:
      description: Firmware variant
      required: true
      default: istore
      type: choice
      options:
        - argon
        - istore
```

Also assert:

- a `Resolve firmware variant` step calls `variant-metadata.sh` and writes its output to `$GITHUB_OUTPUT`;
- all config paths come from `steps.variant.outputs.config_file`, not a fixed `CONFIG_FILE` environment variable;
- the cache key includes `steps.variant.outputs.variant`, source commit and the selected config hash;
- `add-package-feeds.sh` receives the selected variant;
- feed installation runs `./scripts/feeds install -d y -p istore luci-app-store`, `./scripts/feeds install -p nas quickstart`, and `./scripts/feeds install -p nas_luci luci-app-quickstart` only for `istore`, before the general `./scripts/feeds install -a`;
- post-`defconfig` package verification reads `required-packages.sh`;
- release preparation and verification use the dedicated scripts;
- the Release step checks whether the tag already exists before compilation;
- `--prerelease` is added only when metadata says `prerelease=true`;
- `--latest` is `true` only for Argon and `false` for iStore;
- Artifact and Release names use variant and product version, not run number.

- [ ] **Step 2: Prove the old single-config workflow fails**

Run:

```bash
bash tests/test-builder.sh
```

Expected failure: `workflow_dispatch.inputs.variant` is missing.

- [ ] **Step 3: Implement variant resolution and early tag collision check**

Add the workflow input and a step with `id: variant` that appends the exact output of:

```bash
bash .github/scripts/variant-metadata.sh "${{ inputs.variant }}"
```

to `$GITHUB_OUTPUT`. Before installing dependencies or cloning LibWrt, use the GitHub token to fail when `steps.variant.outputs.tag` already exists.

- [ ] **Step 4: Implement conditional feeds and configuration**

Pass the selected variant to the feed script. Update all feeds, then install package definitions in this order:

1. MosDNS feed.
2. For `istore` only: `luci-app-store`, `quickstart`, `luci-app-quickstart` from their named feeds.
3. General feeds.

Copy the selected config to `.config`, run `make defconfig`, and verify every package emitted by `required-packages.sh` is still `=y`.

- [ ] **Step 5: Implement variant-specific cache, artifacts and Release semantics**

Use the selected config in `hashFiles`, include the variant in the cache key and artifact name, invoke both release scripts, then publish:

- Argon with `--latest=true` and without `--prerelease`;
- iStore with `--prerelease --latest=false`.

Release notes must include:

```text
Device: JDCloud AX1800 PRO (RE-SS-01)
Variant: <variant>
Product version: <version>
Source: LiBwrt/LibWrt 25.12-nss (<source commit>)
Builder commit: <github sha>
Config: <config path>
```

- [ ] **Step 6: Verify and commit**

Run:

```bash
ruby -e 'require "yaml"; YAML.safe_load(File.read(".github/workflows/build-re-ss-01.yml"), aliases: true); puts "workflow yaml: ok"'
bash tests/test-builder.sh
git add .github/workflows/build-re-ss-01.yml tests/test-builder.sh
git commit -m "Build and release selectable firmware variants"
```

---

## Task 10: Rewrite user-facing project and safety documentation

**Files:**

- Modify: `README.md`
- Create: `docs/VARIANTS.md`
- Create: `docs/BUILD.md`
- Create: `docs/FLASHING.md`
- Create: `docs/RELEASES.md`
- Create: `CHANGELOG.md`
- Create: `SECURITY.md`
- Modify: `tests/test-builder.sh`

- [ ] **Step 1: Add failing documentation contract tests**

Require the documentation set above and assert:

- README title is exactly `京东云 AX1800 PRO（RE-SS-01）`;
- README links to the renamed repository and all five guides;
- README labels Argon `1.0.0` as stable and iStore `0.1.0-beta.1` as beta;
- VARIANTS states QuickStart is the iStore landing page while Argon renders standard LuCI pages;
- BUILD documents the `variant` choice and version bump before rebuilding the same release;
- FLASHING distinguishes factory and sysupgrade, requires SHA-256 verification, and names `re-ss-01-4-1` as the migration recovery baseline;
- RELEASES documents exact tag and filename patterns and Latest/prerelease policy;
- SECURITY says no default credentials are added, ttyd gets no WAN firewall opening, and the user must set a root password;
- CHANGELOG has entries for `1.0.0` and `0.1.0-beta.1`.

- [ ] **Step 2: Run the test and prove the new docs are missing**

Run:

```bash
bash tests/test-builder.sh
```

Expected failure: `docs/VARIANTS.md` or another required document is absent.

- [ ] **Step 3: Write the documentation**

Keep the instructions Chinese-first and explicitly state:

- this project is not official JDCloud, LibWrt or iStoreOS firmware;
- the current stable recommendation remains the flashed Argon build until beta hardware verification finishes;
- iStore can list packages, but individual store applications are not guaranteed compatible with LibWrt 25.12 or the device;
- no firmware is auto-flashed and no router data is uploaded by the builder;
- after beta build success, physical verification is still required before merging to `main`.

- [ ] **Step 4: Verify links, contracts and commit**

Run:

```bash
bash tests/test-builder.sh
rg -n "OpenWrt360_6\.1|configs/jdcloud-re-ss-01\.config" README.md docs CHANGELOG.md SECURITY.md .github tests configs versions
```

Expected: tests pass and the search returns no stale project/config references except an intentional historical explanation in the design spec.

Run:

```bash
git add README.md docs/VARIANTS.md docs/BUILD.md docs/FLASHING.md docs/RELEASES.md CHANGELOG.md SECURITY.md tests/test-builder.sh
git commit -m "Document RE-SS-01 firmware variants and releases"
```

---

## Task 11: Complete local verification and push the feature branch

**Files:**

- Verify all changed files.

- [ ] **Step 1: Run the full local verification suite**

Run:

```bash
bash tests/test-builder.sh
bash -n .github/scripts/add-package-feeds.sh
bash -n .github/scripts/fix-re-ss-01-factory.sh
bash -n .github/scripts/variant-metadata.sh
bash -n .github/scripts/required-packages.sh
bash -n .github/scripts/prepare-release.sh
bash -n .github/scripts/verify-release.sh
sh -n files/etc/uci-defaults/99-re-ss-01-services
ruby -e 'require "yaml"; YAML.safe_load(File.read(".github/workflows/build-re-ss-01.yml"), aliases: true); puts "workflow yaml: ok"'
```

Expected: every command exits `0`.

- [ ] **Step 2: Check scope and repository cleanliness**

Run:

```bash
git diff main...HEAD --stat
git diff --check main...HEAD
git status --short --branch
git log --oneline main..HEAD
```

Expected: only planned builder/config/docs/tests changes, no whitespace errors, and a clean feature worktree.

- [ ] **Step 3: Push the beta feature branch**

Run:

```bash
git push -u origin feature/istoreos-quickstart
```

Expected: remote branch is created at the renamed repository. Do not merge it.

---

## Task 12: Run the iStore cloud build to a successful prerelease

**External state:**

- Workflow: `.github/workflows/build-re-ss-01.yml`
- Branch: `feature/istoreos-quickstart`
- Variant: `istore`
- Expected tag: `re-ss-01-istore-v0.1.0-beta.1`

- [ ] **Step 1: Trigger the cloud build in GitHub Actions**

From the authenticated GitHub browser, open **Actions → Build JDCloud RE-SS-01 → Run workflow**, select branch `feature/istoreos-quickstart`, choose variant `istore`, and start the run.

Expected: one new run whose branch and variant match exactly.

- [ ] **Step 2: Monitor until success or actionable failure**

Wait for the run. If it fails, open the first failing step and save the exact package/build error before editing. Apply `superpowers:systematic-debugging`: reproduce the failing contract locally when possible, add a regression assertion, implement the smallest fix, rerun all local checks, commit, push and rerun the same `istore` workflow. Repeat until the cloud run succeeds.

Do not weaken these acceptance checks to obtain a green run:

- only RE-SS-01 target;
- all required packages selected;
- aligned factory image;
- complete manifest;
- prerelease semantics;
- deterministic names and checksums.

- [ ] **Step 3: Verify the successful Action and Release**

Confirm in GitHub UI:

- workflow conclusion is `success`;
- Release tag is `re-ss-01-istore-v0.1.0-beta.1`;
- Release is marked **Pre-release** and not **Latest**;
- Release title is `京东云 AX1800 PRO（RE-SS-01）· iStoreOS Dashboard v0.1.0-beta.1`;
- Artifact and Release contain factory, sysupgrade, initramfs, manifest, profiles, build config, build metadata and SHA-256 files;
- factory byte size is a multiple of `65536`;
- manifest contains `luci-app-quickstart`, `quickstart`, `luci-app-store`, `luci-app-ttyd` and every common package.

- [ ] **Step 4: Record the exact build evidence without merging**

Add the successful workflow URL, run number, builder commit, LibWrt source commit and Release URL to the task report. Leave `feature/istoreos-quickstart` open and unmerged for physical testing.

---

## Task 13: Final implementation self-review

**Files:**

- Review all files changed by Tasks 4–10.

- [ ] **Step 1: Check approved-spec coverage**

Verify each section of `docs/superpowers/specs/2026-09-05-dual-firmware-release-design.md` maps to an implemented test, script, workflow rule or document. Pay special attention to:

- QuickStart landing-page behavior;
- Argon/Bootstrap retention inside the iStore image;
- stable versus prerelease semantics;
- no service/IP/storage/swap mutation;
- recovery guidance;
- no merge before hardware acceptance.

- [ ] **Step 2: Scan for placeholders and stale names**

Run:

```bash
rg -n "[T]BD|[T]ODO|[F]IXME|OpenWrt360_6\.1|configs/jdcloud-re-ss-01\.config|re-ss-01-\$\{GITHUB_RUN_NUMBER\}" . --glob '!docs/superpowers/specs/**' --glob '!docs/superpowers/plans/**' --glob '!.git/**'
```

Expected: no output.

- [ ] **Step 3: Check type and naming consistency**

Verify the same exact identifiers are used across scripts, tests, workflow and docs:

```text
variant: argon | istore
argon version: 1.0.0
istore version: 0.1.0-beta.1
argon config: configs/re-ss-01-argon.config
istore config: configs/re-ss-01-istore.config
device: jdcloud_re-ss-01
repository: xiaofu2415/JDCloud-AX1800-Pro-RE-SS-01
```

- [ ] **Step 4: Run verification-before-completion**

Run the complete local verification from Task 11 again and review the successful cloud run and Release from Task 12. Only then report the beta compilation as successful. Clearly mark physical-router testing as not yet performed.

## Deferred Physical Acceptance

After the user downloads and flashes the beta, perform these separately:

1. Verify boot, WAN, LAN, Wi-Fi, LuCI and SSH.
2. Verify login lands on `/cgi-bin/luci/admin/quickstart/`.
3. Verify QuickStart displays WAN, interfaces, memory, overlay and eMMC information correctly.
4. Verify iStore loads its list; treat each installed store app as a separate compatibility test.
5. Verify LuCI terminal works from LAN and is unreachable from WAN.
6. Verify Argon standard pages and Bootstrap recovery theme.
7. Verify optional services remain disabled and nlbwmon policy is correct.
8. Verify a normal restart and a cold power cycle.
9. Only after those checks, merge the feature branch to `main` and decide whether to promote a later iStore version beyond beta.
