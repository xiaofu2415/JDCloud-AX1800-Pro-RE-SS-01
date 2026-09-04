#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$repo_root/.github/workflows/build-re-ss-01.yml"
config="$repo_root/configs/jdcloud-re-ss-01.config"

ruby - "$workflow" "$config" "$repo_root" <<'RUBY'
require "yaml"

workflow_path, config_path, repo_root = ARGV
abort "missing RE-SS-01 workflow" unless File.file?(workflow_path)
abort "missing RE-SS-01 config" unless File.file?(config_path)

workflow = YAML.safe_load(File.read(workflow_path), aliases: true)
abort "workflow must be manually triggered" unless workflow.dig("on", "workflow_dispatch") == {}
abort "scheduled builds must stay disabled" if workflow.fetch("on", {}).key?("schedule")
abort "release job needs contents: write" unless workflow.dig("permissions", "contents") == "write"

env = workflow.fetch("env")
abort "wrong upstream source" unless env["SOURCE_REPOSITORY"] == "https://github.com/LiBwrt/LibWrt.git"
abort "wrong upstream branch" unless env["SOURCE_BRANCH"] == "25.12-nss"
abort "wrong config path" unless env["CONFIG_FILE"] == "configs/jdcloud-re-ss-01.config"

steps = workflow.dig("jobs", "build", "steps")
checkout = steps.find { |step| step["uses"] == "actions/checkout@v4" }
abort "checkout credentials must not persist into upstream build steps" unless checkout.dig("with", "persist-credentials") == false

load_config = steps.find { |step| step["name"] == "Load RE-SS-01 configuration" }
abort "configuration must be expanded from the OpenWrt source directory" unless load_config["working-directory"] == "openwrt"

config = File.readlines(config_path, chomp: true)
selected_devices = config.grep(/^CONFIG_TARGET_qualcommax_ipq60xx_DEVICE_.+=y$/)
expected_device = "CONFIG_TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y"
abort "config must select only RE-SS-01" unless selected_devices == [expected_device]

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
