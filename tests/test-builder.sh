#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$repo_root/.github/workflows/build-re-ss-01.yml"
metadata_script="$repo_root/.github/scripts/variant-metadata.sh"
factory_aligner="$repo_root/.github/scripts/fix-re-ss-01-factory.sh"
factory_fixture="$repo_root/tests/fixtures/ipq60xx.mk"
defaults="$repo_root/files/etc/uci-defaults/zz-re-ss-01-services"

ruby - "$workflow" "$metadata_script" "$repo_root" <<'RUBY'
require "yaml"
require "open3"
require "tmpdir"

workflow_path, metadata_script, repo_root = ARGV
abort "missing RE-SS-01 workflow" unless File.file?(workflow_path)
abort "missing variant metadata script" unless File.file?(metadata_script)
abort "variant metadata script must be executable" unless File.executable?(metadata_script)

variants = {
  "argon" => {
    "config" => "configs/re-ss-01-argon.config",
    "version" => "1.0.0",
    "tag" => "re-ss-01-argon-v1.0.0",
    "artifact_name" => "jdcloud-re-ss-01-libwrt-argon-v1.0.0",
    "release_title" => "京东云 AX1800 PRO（RE-SS-01）· Argon v1.0.0",
    "prerelease" => "false"
  },
  "istore" => {
    "config" => "configs/re-ss-01-istore.config",
    "version" => "0.1.0-beta.1",
    "tag" => "re-ss-01-istore-v0.1.0-beta.1",
    "artifact_name" => "jdcloud-re-ss-01-libwrt-istore-v0.1.0-beta.1",
    "release_title" => "京东云 AX1800 PRO（RE-SS-01）· iStoreOS Dashboard v0.1.0-beta.1",
    "prerelease" => "true"
  }
}

common_packages = %w[
  CONFIG_PACKAGE_luci-app-passwall2=y
  CONFIG_PACKAGE_luci-app-mosdns=y
  CONFIG_PACKAGE_luci-app-adguardhome=y
  CONFIG_PACKAGE_luci-app-nlbwmon=y
  CONFIG_PACKAGE_luci-app-dockerman=y
  CONFIG_PACKAGE_tailscale=y
  CONFIG_PACKAGE_luci-app-sqm=y
  CONFIG_PACKAGE_sqm-scripts-nss=y
  CONFIG_PACKAGE_luci-theme-argon=y
  CONFIG_PACKAGE_luci-theme-bootstrap=y
]

variants.each do |variant, expected|
  config_path = File.join(repo_root, expected.fetch("config"))
  abort "missing #{variant} config" unless File.file?(config_path)
  abort "missing #{variant} version" unless File.read(File.join(repo_root, "versions", "#{variant}.version")).strip == expected.fetch("version")

  config = File.readlines(config_path, chomp: true)
  selected_devices = config.grep(/^CONFIG_TARGET_qualcommax_ipq60xx_DEVICE_.+=y$/)
  expected_device = "CONFIG_TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y"
  abort "#{variant} config must select only RE-SS-01" unless selected_devices == [expected_device]
  missing_packages = common_packages.reject { |entry| config.include?(entry) }
  abort "#{variant} config missing common packages: #{missing_packages.join(', ')}" unless missing_packages.empty?

  output, status = Dir.mktmpdir do |directory|
    Open3.capture2e(metadata_script, variant, chdir: directory)
  end
  abort "#{variant} metadata failed: #{output}" unless status.success?
  expected_output = [
    "variant=#{variant}",
    "config_file=#{expected.fetch('config')}",
    "version=#{expected.fetch('version')}",
    "tag=#{expected.fetch('tag')}",
    "artifact_name=#{expected.fetch('artifact_name')}",
    "release_title=#{expected.fetch('release_title')}",
    "prerelease=#{expected.fetch('prerelease')}"
  ].join("\n") + "\n"
  abort "#{variant} metadata output is not exact" unless output == expected_output
end

invalid_output, invalid_status = Open3.capture2e(metadata_script, "invalid")
abort "unknown variant must exit 2" unless invalid_status.exitstatus == 2

workflow = YAML.safe_load(File.read(workflow_path), aliases: true)
abort "workflow must be manually triggered" unless workflow.dig("on", "workflow_dispatch") == {}
abort "scheduled builds must stay disabled" if workflow.fetch("on", {}).key?("schedule")
abort "release job needs contents: write" unless workflow.dig("permissions", "contents") == "write"

env = workflow.fetch("env")
abort "wrong upstream source" unless env["SOURCE_REPOSITORY"] == "https://github.com/LiBwrt/LibWrt.git"
abort "wrong upstream branch" unless env["SOURCE_BRANCH"] == "25.12-nss"

steps = workflow.dig("jobs", "build", "steps")
checkout = steps.find { |step| step["uses"] == "actions/checkout@v4" }
abort "checkout credentials must not persist into upstream build steps" unless checkout.dig("with", "persist-credentials") == false

load_config = steps.find { |step| step["name"] == "Load RE-SS-01 configuration" }
abort "configuration must be expanded from the OpenWrt source directory" unless load_config["working-directory"] == "openwrt"

alignment = steps.find { |step| step["name"] == "Align RE-SS-01 factory image" }
abort "missing RE-SS-01 factory alignment step" unless alignment
aligner_call = "bash .github/scripts/fix-re-ss-01-factory.sh openwrt/target/linux/qualcommax/image/ipq60xx.mk"
abort "factory alignment step must patch the cloned source" unless alignment["run"] == aligner_call
alignment_index = steps.index(alignment)
compile_index = steps.index { |step| step["name"] == "Compile firmware" }
abort "factory alignment must run before compilation" unless alignment_index < compile_index

cache = steps.find { |step| step["uses"] == "actions/cache@v4" }
abort "missing download and compiler cache" unless cache
cache_paths = cache.dig("with", "path").lines.map(&:strip).reject(&:empty?)
abort "cache must contain only downloads and ccache" unless cache_paths == %w[openwrt/dl openwrt/.ccache]
cache_key = cache.dig("with", "key")
expected_key = "re-ss-01-${{ runner.os }}-${{ env.SOURCE_BRANCH }}-${{ steps.source.outputs.commit }}-${{ hashFiles(env.CONFIG_FILE) }}"
abort "cache key must track runner, branch, source and config" unless cache_key == expected_key
restore_keys = cache.dig("with", "restore-keys").lines.map(&:strip).reject(&:empty?)
abort "cache must reuse the latest compatible branch entry" unless restore_keys == ["re-ss-01-${{ runner.os }}-${{ env.SOURCE_BRANCH }}-"]
cache_index = steps.index(cache)
feeds_index = steps.index { |step| step["name"] == "Install feeds" }
abort "cache must restore after clone and before feeds" unless cache_index > alignment_index && cache_index < feeds_index

feeds_install = steps.fetch(feeds_index).fetch("run")
mosdns_install_index = feeds_install.index("./scripts/feeds install -p mosdns -a")
all_feeds_install_index = feeds_install.index("./scripts/feeds install -a")
abort "MosDNS feed must be installed before the general feeds" unless mosdns_install_index && all_feeds_install_index && mosdns_install_index < all_feeds_install_index

argon_config = File.readlines(File.join(repo_root, variants.fetch("argon").fetch("config")), chomp: true)
abort "ccache must be enabled" unless argon_config.include?("CONFIG_CCACHE=y")
abort "PassWall2 must use Xray core" unless argon_config.include?("CONFIG_PACKAGE_luci-app-passwall2_Basic_Core_Xray=y")
abort "PassWall2 must use nftables" unless argon_config.include?("CONFIG_PACKAGE_luci-app-passwall2_Nftables_Transparent_Proxy=y")
abort "PassWall2 all-core bundle must stay disabled" unless argon_config.include?("# CONFIG_PACKAGE_luci-app-passwall2_Basic_Core_All is not set")

custom_feeds = steps.find { |step| step["name"] == "Add requested package feeds" }
abort "missing requested package feeds step" unless custom_feeds
abort "custom feeds must be added before feed installation" unless steps.index(custom_feeds) < feeds_index
abort "custom feeds script is not used" unless custom_feeds["run"] == "bash .github/scripts/add-package-feeds.sh openwrt/feeds.conf.default"

abort "missing last-running first-boot service defaults" unless File.file?(File.join(repo_root, "files/etc/uci-defaults/zz-re-ss-01-services"))
abort "firmware files must be copied before configuration" unless steps.any? { |step| step["name"] == "Install RE-SS-01 defaults" }

workflows = Dir.glob(File.join(repo_root, ".github/workflows/*.{yml,yaml}"))
abort "legacy workflows still present" unless workflows == [workflow_path]

legacy_paths = %w[
  0001-fix-upnp.patch
  build.sh
  diy-mini.sh
  diy-script.sh
  docker
  feeds
  images
  scripts
]
present_legacy_paths = legacy_paths.select { |path| File.exist?(File.join(repo_root, path)) }
abort "legacy build assets still present: #{present_legacy_paths.join(', ')}" unless present_legacy_paths.empty?
RUBY

echo "builder contract: ok"

fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT
cp "$factory_fixture" "$fixture_root/ipq60xx.mk"
bash "$factory_aligner" "$fixture_root/ipq60xx.mk"

ruby - "$fixture_root/ipq60xx.mk" <<'RUBY'
path = ARGV.fetch(0)
source = File.read(path)

device = source[/define Device\/jdcloud_re-ss-01\n.*?^endef$/m]
abort "RE-SS-01 fixture definition missing" unless device
expected = "IMAGE/factory.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-rootfs | pad-rootfs | pad-to 64k"
abort "RE-SS-01 factory image is not 64 KiB aligned" unless device.include?(expected)
abort "RE-SS-01 factory image still appends metadata" if device.include?("append-metadata")

neighbor = source[/define Device\/redmi_ax5-jdcloud\n.*?^endef$/m]
abort "neighbor fixture definition changed" unless neighbor&.include?("append-rootfs | append-metadata")
RUBY

echo "factory alignment transform: ok"

defaults_text="$(sed -n '1,240p' "$defaults")"
grep -Fq "for service in passwall2 mosdns adguardhome dockerd tailscale sqm" <<<"$defaults_text" || {
  echo "all optional services must be covered by the first-boot policy" >&2
  exit 1
}
grep -Fq '/etc/init.d/$service disable' <<<"$defaults_text" || {
  echo "optional services must be disabled on first boot" >&2
  exit 1
}
grep -Fq "database_generations='3'" <<<"$defaults_text" || {
  echo "nlbwmon history must be limited to three generations" >&2
  exit 1
}
grep -Fq "mediaurlbase='/luci-static/argon'" <<<"$defaults_text" || {
  echo "Argon must be the default LuCI theme" >&2
  exit 1
}

echo "requested packages and defaults: ok"
