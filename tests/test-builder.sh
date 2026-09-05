#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$repo_root/.github/workflows/build-re-ss-01.yml"
metadata_script="$repo_root/.github/scripts/variant-metadata.sh"
factory_aligner="$repo_root/.github/scripts/fix-re-ss-01-factory.sh"
factory_fixture="$repo_root/tests/fixtures/ipq60xx.mk"
defaults="$repo_root/files/etc/uci-defaults/99-re-ss-01-services"
required_packages="$repo_root/.github/scripts/required-packages.sh"

ruby - "$repo_root" <<'RUBY'
repo = ARGV.fetch(0)
paths = %w[
  README.md
  docs/VARIANTS.md
  docs/BUILD.md
  docs/FLASHING.md
  docs/RELEASES.md
  CHANGELOG.md
  SECURITY.md
]
paths.each do |path|
  abort "missing documentation: #{path}" unless File.file?(File.join(repo, path))
end

read = lambda { |path| File.read(File.join(repo, path)) }
require_text = lambda do |path, text, label|
  abort "#{path} must document #{label}" unless read.call(path).include?(text)
end
require_match = lambda do |path, pattern, label|
  abort "#{path} must document #{label}" unless read.call(path).match?(pattern)
end

readme = read.call("README.md")
abort "README title must be exact" unless readme.lines.first&.chomp == "# 京东云 AX1800 PRO（RE-SS-01）"
require_text.call("README.md", "https://github.com/xiaofu2415/JDCloud-AX1800-Pro-RE-SS-01", "the renamed repository")
%w[VARIANTS BUILD FLASHING RELEASES].each do |guide|
  require_text.call("README.md", "docs/#{guide}.md", "the #{guide} guide link")
end
require_text.call("README.md", "SECURITY.md", "the SECURITY guide link")
require_match.call("README.md", /Argon.{0,40}`1\.0\.0`.{0,40}(稳定|stable)/i, "Argon 1.0.0 as stable")
require_match.call("README.md", /iStore.{0,40}`0\.1\.0-beta\.1`.{0,40}(测试|实验|beta)/i, "iStore 0.1.0-beta.1 as beta")

require_match.call("docs/VARIANTS.md", /QuickStart.{0,40}(首页|落地页)/i, "QuickStart as the iStore landing page")
require_match.call("docs/VARIANTS.md", /Argon.{0,60}(标准|普通).{0,20}LuCI|标准 LuCI.{0,40}Argon/i, "Argon for standard LuCI pages")
require_match.call("docs/BUILD.md", /variant.{0,40}(argon|istore)/i, "manual variant choice")
require_match.call("docs/BUILD.md", /(重建|重新构建).{0,50}(同一|相同).{0,20}(版本|Release).{0,50}(更新|提升|递增).{0,20}版本|版本.{0,50}(更新|提升|递增).{0,50}(重建|重新构建)/i, "a version bump before rebuilding the same release")
require_match.call("docs/FLASHING.md", /factory.{0,120}sysupgrade|sysupgrade.{0,120}factory/i, "factory and sysupgrade differences")
require_match.call("docs/FLASHING.md", /SHA-256/i, "SHA-256 verification")
require_text.call("docs/FLASHING.md", "re-ss-01-4-1", "the migration recovery baseline")
%w[re-ss-01-argon-v1.0.0 re-ss-01-istore-v0.1.0-beta.1].each do |tag|
  require_text.call("docs/RELEASES.md", tag, "exact release tag #{tag}")
end
%w[
  jdcloud-re-ss-01-libwrt-argon-v1.0.0-squashfs-factory.bin
  jdcloud-re-ss-01-libwrt-argon-v1.0.0-squashfs-sysupgrade.bin
  jdcloud-re-ss-01-libwrt-istore-v0.1.0-beta.1-squashfs-factory.bin
  jdcloud-re-ss-01-libwrt-istore-v0.1.0-beta.1-squashfs-sysupgrade.bin
].each do |filename|
  require_text.call("docs/RELEASES.md", filename, "exact release filename #{filename}")
end
require_match.call("docs/RELEASES.md", /Latest.{0,100}Argon|Argon.{0,100}Latest/i, "Argon Latest policy")
require_match.call("docs/RELEASES.md", /(Prerelease|预发布).{0,100}iStore|iStore.{0,100}(Prerelease|预发布)/i, "iStore prerelease policy")

require_match.call("SECURITY.md", /(不预置|不提供|没有).{0,30}(默认|初始).{0,20}(凭据|密码|账户)/, "no default credentials")
require_match.call("SECURITY.md", /ttyd.{0,80}(不新增|不开放|没有).{0,30}WAN/i, "no ttyd WAN firewall opening")
require_match.call("SECURITY.md", /(必须|务必).{0,20}(设置|修改).{0,20}root.{0,10}密码|root.{0,10}密码.{0,20}(必须|务必)/i, "the root-password requirement")
require_text.call("CHANGELOG.md", "## 1.0.0", "the 1.0.0 entry")
require_text.call("CHANGELOG.md", "## 0.1.0-beta.1", "the 0.1.0-beta.1 entry")

disclaimer = "本项目不是京东云、LibWrt 或 iStoreOS 的官方固件"
require_text.call("README.md", disclaimer, "the unofficial firmware disclaimer")
require_match.call("README.md", /Argon.{0,80}(稳定推荐|推荐).{0,80}(beta|测试).{0,40}(真机|硬件).{0,20}(验证|验收)/i, "Argon as the stable recommendation until beta hardware validation")
require_match.call("docs/VARIANTS.md", /iStore.{0,60}(应用|软件).{0,60}(不保证|无法保证).{0,80}(兼容|可用).{0,80}LibWrt 25\.12/i, "the iStore application compatibility warning")
require_match.call("docs/BUILD.md", /(不会|不).{0,20}(自动刷|自动写入).{0,50}(不会|不).{0,20}(上传|传出).{0,30}(路由器|设备).{0,20}数据/, "no auto-flash or router data upload")
require_match.call("docs/BUILD.md", /(beta|测试).{0,30}(构建|编译).{0,30}(成功|完成).{0,80}(真机|硬件).{0,30}(验证|验收).{0,80}(合并|merge).{0,20}`main`/i, "physical validation before merging")

puts "documentation contracts: ok"
RUBY

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
  CONFIG_CCACHE=y
  CONFIG_LUCI_LANG_zh_Hans=y
  CONFIG_PACKAGE_luci-app-passwall2=y
  CONFIG_PACKAGE_luci-app-passwall2_Basic_Core_Xray=y
  CONFIG_PACKAGE_luci-app-passwall2_Nftables_Transparent_Proxy=y
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
common_packages << "# CONFIG_PACKAGE_luci-app-passwall2_Basic_Core_All is not set"

istore_only_packages = %w[
  CONFIG_PACKAGE_luci-app-ttyd=y
  CONFIG_PACKAGE_luci-app-store=y
  CONFIG_PACKAGE_quickstart=y
  CONFIG_PACKAGE_luci-app-quickstart=y
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

argon_config = File.readlines(File.join(repo_root, variants.fetch("argon").fetch("config")), chomp: true)
istore_config = File.readlines(File.join(repo_root, variants.fetch("istore").fetch("config")), chomp: true)
abort "iStore config must add exactly the dashboard packages" unless istore_config == argon_config + istore_only_packages

invalid_output, invalid_status = Open3.capture2e(metadata_script, "invalid")
abort "unknown variant must exit 2" unless invalid_status.exitstatus == 2

workflow = YAML.safe_load(File.read(workflow_path), aliases: true)
variant_input = workflow.dig("on", "workflow_dispatch", "inputs", "variant")
abort "workflow_dispatch.inputs.variant is missing" unless variant_input
abort "wrong firmware variant input" unless variant_input == {
  "description" => "Firmware variant", "required" => true, "default" => "istore",
  "type" => "choice", "options" => %w[argon istore]
}
abort "workflow must be manual-only" unless workflow.fetch("on").keys == ["workflow_dispatch"]
abort "scheduled builds must stay disabled" if workflow.fetch("on", {}).key?("schedule")
abort "release job needs contents: write" unless workflow.dig("permissions", "contents") == "write"
abort "build timeout must stay 360 minutes" unless workflow.dig("jobs", "build", "timeout-minutes") == 360

env = workflow.fetch("env")
abort "wrong upstream source" unless env["SOURCE_REPOSITORY"] == "https://github.com/LiBwrt/LibWrt.git"
abort "wrong upstream branch" unless env["SOURCE_BRANCH"] == "25.12-nss"
abort "fixed CONFIG_FILE must not select the variant" if File.read(workflow_path).include?("CONFIG_FILE")

steps = workflow.dig("jobs", "build", "steps")
step_named = lambda do |name|
  steps.find { |step| step["name"] == name } || abort("missing workflow step: #{name}")
end
checkout = steps.find { |step| step["uses"] == "actions/checkout@v4" }
abort "checkout credentials must not persist into upstream build steps" unless checkout.dig("with", "persist-credentials") == false

resolver = step_named.call("Resolve firmware variant")
abort "variant resolution needs id: variant" unless resolver["id"] == "variant"
abort "variant output must be appended verbatim" unless resolver["run"].strip == 'bash .github/scripts/variant-metadata.sh "${{ inputs.variant }}" >> "$GITHUB_OUTPUT"'
abort "variant resolution must follow checkout" unless steps.index(checkout) < steps.index(resolver)

tag_check = step_named.call("Reject existing product-version tag")
abort "tag check must authenticate with the GitHub token" unless tag_check.dig("env", "GH_TOKEN") == '${{ github.token }}'
abort "tag check must use the product tag" unless tag_check.dig("env", "RELEASE_TAG") == '${{ steps.variant.outputs.tag }}'
["Install build dependencies", "Clone current LibWrt source", "Compile firmware"].each do |name|
  abort "tag collision must fail before #{name}" unless steps.index(resolver) < steps.index(tag_check) && steps.index(tag_check) < steps.index(step_named.call(name))
end

load_config = steps.find { |step| step["name"] == "Load RE-SS-01 configuration" }
abort "configuration must be expanded from the OpenWrt source directory" unless load_config["working-directory"] == "openwrt"
abort "load selected variant config before defconfig" unless load_config["run"].match?(/cp "\$GITHUB_WORKSPACE\/\$\{\{ steps\.variant\.outputs\.config_file \}\}" \.config\s+make defconfig/)

package_check = step_named.call("Verify requested packages")
abort "verify packages after defconfig" unless steps.index(package_check) > steps.index(load_config) && package_check["working-directory"] == "openwrt"
abort "package verification must use the variant policy" unless package_check["run"].include?('packages="$(bash "$GITHUB_WORKSPACE/.github/scripts/required-packages.sh" "${{ steps.variant.outputs.variant }}")"')
abort "package verification must check every selected package" unless package_check["run"].include?('while IFS= read -r package; do') && package_check["run"].include?('grep -qx "CONFIG_PACKAGE_${package}=y" .config') && package_check["run"].include?('done <<< "$packages"')

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
expected_key = "re-ss-01-${{ runner.os }}-${{ env.SOURCE_BRANCH }}-${{ steps.variant.outputs.variant }}-${{ steps.source.outputs.commit }}-${{ hashFiles(steps.variant.outputs.config_file) }}"
abort "cache key must track runner, branch, variant, source and selected config" unless cache_key == expected_key
restore_keys = cache.dig("with", "restore-keys").lines.map(&:strip).reject(&:empty?)
abort "cache restore must stay within the selected variant" unless restore_keys == ["re-ss-01-${{ runner.os }}-${{ env.SOURCE_BRANCH }}-${{ steps.variant.outputs.variant }}-"]
cache_index = steps.index(cache)
feeds_index = steps.index { |step| step["name"] == "Install feeds" }
abort "cache must restore after clone and before feeds" unless cache_index > alignment_index && cache_index < feeds_index

feeds_install = steps.fetch(feeds_index).fetch("run")
mosdns_install_index = feeds_install.index("./scripts/feeds install -p mosdns -a")
all_feeds_install_index = feeds_install.index("./scripts/feeds install -a")
abort "MosDNS feed must be installed before the general feeds" unless mosdns_install_index && all_feeds_install_index && mosdns_install_index < all_feeds_install_index

custom_feeds = steps.find { |step| step["name"] == "Add requested package feeds" }
abort "missing requested package feeds step" unless custom_feeds
abort "custom feeds must be added before feed installation" unless steps.index(custom_feeds) < feeds_index
abort "custom feeds script must receive selected variant" unless custom_feeds["run"] == 'bash .github/scripts/add-package-feeds.sh openwrt/feeds.conf.default "${{ steps.variant.outputs.variant }}"'

prepare = step_named.call("Prepare RE-SS-01 release")
verify = step_named.call("Verify RE-SS-01 release")
prepare_call = 'bash .github/scripts/prepare-release.sh openwrt/bin/targets/qualcommax/ipq60xx output "${{ steps.variant.outputs.variant }}" "${{ steps.variant.outputs.version }}" "${{ steps.source.outputs.commit }}" "${{ github.sha }}" "${{ steps.variant.outputs.config_file }}"'
abort "release preparation arguments must follow the script contract" unless prepare["run"].gsub(/[ \t]*\\\n\s*/, " ").strip == prepare_call
abort "release verification arguments must follow the script contract" unless verify["run"].strip == 'bash .github/scripts/verify-release.sh output "${{ steps.variant.outputs.variant }}" "${{ steps.variant.outputs.version }}"'
artifact = step_named.call("Upload workflow artifact")
release = step_named.call("Publish GitHub release")
abort "artifact must use the variant/version metadata name" unless artifact.dig("with", "name") == '${{ steps.variant.outputs.artifact_name }}'
abort "artifact must upload verified output" unless artifact.dig("with", "path") == "output/" && artifact.dig("with", "if-no-files-found") == "error"
ordered = [step_named.call("Compile firmware"), prepare, verify, artifact, release].map { |step| steps.index(step) }
abort "release must be prepared and verified before upload/publication" unless ordered == ordered.sort && ordered.uniq == ordered
abort "release names must not depend on run number or attempt" if File.read(workflow_path).match?(/github\.run_(number|attempt)|GITHUB_RUN_(NUMBER|ATTEMPT)/)
release_env = {
  "GH_TOKEN" => '${{ github.token }}', "VARIANT" => '${{ steps.variant.outputs.variant }}',
  "VERSION" => '${{ steps.variant.outputs.version }}', "RELEASE_TAG" => '${{ steps.variant.outputs.tag }}',
  "RELEASE_TITLE" => '${{ steps.variant.outputs.release_title }}', "PRERELEASE" => '${{ steps.variant.outputs.prerelease }}',
  "SOURCE_COMMIT" => '${{ steps.source.outputs.commit }}', "BUILDER_COMMIT" => '${{ github.sha }}',
  "SELECTED_CONFIG" => '${{ steps.variant.outputs.config_file }}'
}
release_env.each do |key, value|
  abort "release metadata is not wired: #{key}" unless release.dig("env", key) == value
end

# Execute the actual run snippets; external build and GitHub commands are bounded doubles.
steps.each do |step|
  next unless step["run"]
  shell = step["run"].gsub(/\$\{\{.*?\}\}/, "test-value")
  output, status = Open3.capture2e("bash", "-n", stdin_data: shell)
  abort "invalid shell in #{step['name']}: #{output}" unless status.success?
end
Dir.mktmpdir("workflow-contract-") do |directory|
  scripts = File.join(directory, "scripts")
  Dir.mkdir(scripts)
  File.write(File.join(scripts, "feeds"), "#!/usr/bin/env bash\nprintf '%s\\n' \"$*\"\n")
  File.chmod(0755, File.join(scripts, "feeds"))
  variants.each do |variant, expected|
    output_file = File.join(directory, "github-output")
    File.write(output_file, "existing=keep\n")
    shell = resolver.fetch("run").gsub('${{ inputs.variant }}', variant)
    output, status = Open3.capture2e({"GITHUB_OUTPUT" => output_file}, "bash", "-euo", "pipefail", "-c", shell, chdir: repo_root)
    metadata, metadata_status = Open3.capture2e(metadata_script, variant)
    abort "#{variant} resolver must preserve existing outputs and append metadata verbatim: #{output}" unless status.success? && metadata_status.success? && File.read(output_file) == "existing=keep\n" + metadata

    config_path = File.join(directory, ".config")
    policy, policy_status = Open3.capture2e("bash", File.join(repo_root, ".github/scripts/required-packages.sh"), variant)
    abort "#{variant} package policy failed" unless policy_status.success?
    config = policy.lines.map { |package| "CONFIG_PACKAGE_#{package.strip}=y\n" }.join
    package_shell = package_check.fetch("run").gsub('${{ steps.variant.outputs.variant }}', variant)
    [config, config.sub(/=y\n/, "=m\n")].each_with_index do |contents, index|
      File.write(config_path, contents)
      output, status = Open3.capture2e({"GITHUB_WORKSPACE" => repo_root}, "bash", "-euo", "pipefail", "-c", package_shell, chdir: directory)
      abort "#{variant} post-defconfig package check is wrong: #{output}" unless status.success? == (index == 0)
    end

    shell = feeds_install.gsub('${{ steps.variant.outputs.variant }}', variant)
    output, status = Open3.capture2e("bash", "-euo", "pipefail", "-c", shell, chdir: directory)
    commands = ["update -a", "install -p mosdns -a"]
    commands += ["install -d y -p istore luci-app-store", "install -p nas quickstart", "install -p nas_luci luci-app-quickstart"] if variant == "istore"
    commands << "install -a"
    abort "#{variant} named-feed installation order/condition is wrong: #{output}" unless status.success? && output.lines.map(&:strip) == commands

    values = {"GITHUB_REPOSITORY" => "owner/repo", "VARIANT" => variant, "VERSION" => expected.fetch("version"),
      "RELEASE_TAG" => expected.fetch("tag"), "RELEASE_TITLE" => expected.fetch("release_title"),
      "PRERELEASE" => expected.fetch("prerelease"), "SOURCE_BRANCH" => "25.12-nss",
      "SOURCE_COMMIT" => "source-sha", "BUILDER_COMMIT" => "builder-sha", "SELECTED_CONFIG" => expected.fetch("config")}
    shell = "gh() { printf '<%s>\\n' \"$@\"; }\n" + release.fetch("run")
    output, status = Open3.capture2e(values, "bash", "-euo", "pipefail", "-c", shell, chdir: directory)
    abort "#{variant} release command failed: #{output}" unless status.success?
    ["<release>\n<create>\n<#{expected.fetch('tag')}>", "<--repo>\n<owner/repo>", "<--target>\n<builder-sha>", "<--title>\n<#{expected.fetch('release_title')}>", "<--latest=#{variant == 'argon'}>"].each do |argument|
      abort "#{variant} release argument missing: #{argument}" unless output.include?(argument)
    end
    abort "#{variant} prerelease flag is wrong" unless output.include?("<--prerelease>") == (variant == "istore")
    notes = "Device: JDCloud AX1800 PRO (RE-SS-01)\nVariant: #{variant}\nProduct version: #{expected.fetch('version')}\nSource: LiBwrt/LibWrt 25.12-nss (source-sha)\nBuilder commit: builder-sha\nConfig: #{expected.fetch('config')}"
    abort "#{variant} release notes are not exact" unless output.include?("<--notes>\n<#{notes}>")
  end

  # A missing exact tag passes; a same-prefix tag must not be a collision.
  {"" => true, "refs/tags/re-ss-01-istore-v0.1.0-beta.1-extra" => true,
   "refs/tags/re-ss-01-istore-v0.1.0-beta.1" => false}.each do |refs, success|
    shell = <<~'SHELL'
      gh() {
        [[ "$*" == "api repos/owner/repo/git/matching-refs/tags/re-ss-01-istore-v0.1.0-beta.1 --jq .[].ref" ]] || return 97
        printf '%s\n' "$TEST_REFS"
      }
    SHELL
    shell += tag_check.fetch("run")
    output, status = Open3.capture2e({"TEST_REFS" => refs, "RELEASE_TAG" => "re-ss-01-istore-v0.1.0-beta.1", "GITHUB_REPOSITORY" => "owner/repo"}, "bash", "-euo", "pipefail", "-c", shell)
    abort "tag collision policy is wrong for #{refs}: #{output}" unless status.success? == success
  end
  shell = "gh() { return 1; }\n" + tag_check.fetch("run")
  _, status = Open3.capture2e({"RELEASE_TAG" => "tag", "GITHUB_REPOSITORY" => "owner/repo"}, "bash", "-euo", "pipefail", "-c", shell)
  abort "tag lookup failure must stop the build" if status.success?
end
puts "dual-variant workflow contracts and shell snippets: ok"

abort "missing last-running first-boot service defaults" unless File.file?(File.join(repo_root, "files/etc/uci-defaults/99-re-ss-01-services"))
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

assert_first_boot_policy() {
  local policy_file="$1"
  local executable_text expected_executable

  executable_text="$(sed -E '/^[[:space:]]*$/d; /^[[:space:]]*#[^!]/d; s/[[:space:]]+#.*$//' "$policy_file")"
  expected_executable="$(cat <<'EOF'
#!/bin/sh
for service in passwall2 mosdns adguardhome dockerd tailscale sqm; do
	[ -x "/etc/init.d/$service" ] && /etc/init.d/$service disable
done
uci -q set passwall2.@global[0].enabled='0'
uci -q set mosdns.config.enabled='0'
uci -q set adguardhome.config.enabled='0'
uci -q set nlbwmon.@nlbwmon[0].database_generations='3'
uci -q set luci.themes.Argon='/luci-static/argon'
uci -q set luci.main.mediaurlbase='/luci-static/argon'
uci -q commit passwall2
uci -q commit mosdns
uci -q commit adguardhome
uci -q commit nlbwmon
uci -q commit luci
exit 0
EOF
)"

  if [[ "$executable_text" != "$expected_executable" ]]; then
    echo "first-boot defaults executable sequence must match the safe policy exactly" >&2
    return 1
  fi
}

assert_first_boot_policy "$defaults"

assert_policy_rejects_mutation() {
  local name="$1" mutation="$2" policy_file
  policy_file="$fixture_root/${name}.uci-defaults"
  cp "$defaults" "$policy_file"
  printf '%s\n' "$mutation" >> "$policy_file"
  if assert_first_boot_policy "$policy_file" >/dev/null 2>&1; then
    echo "first-boot policy must reject mutation: $name" >&2
    exit 1
  fi
  echo "first-boot policy mutation rejected: $name"
}

late_policy_file="$fixture_root/after-line-240.uci-defaults"
cp "$defaults" "$late_policy_file"
while [[ "$(wc -l < "$late_policy_file")" -lt 240 ]]; do
  printf '\n' >> "$late_policy_file"
done
printf "%s\n" "uci -q set network.lan.ipaddr='192.168.99.1'" >> "$late_policy_file"
if assert_first_boot_policy "$late_policy_file" >/dev/null 2>&1; then
  echo "first-boot policy must inspect commands appended after line 240" >&2
  exit 1
fi
echo "first-boot policy mutation rejected: after-line-240"

assert_policy_rejects_mutation service-enable '/etc/init.d/sqm enable'
assert_policy_rejects_mutation nlbwmon-disable '/etc/init.d/nlbwmon disable'
assert_policy_rejects_mutation wrong-generations "uci -q set nlbwmon.@nlbwmon[0].database_generations='10'"
assert_policy_rejects_mutation firewall-uci 'uci -q set firewall.safe=1'
assert_policy_rejects_mutation quickstart-redirect "uci -q set luci.main.homepage='/admin/quickstart'"
assert_policy_rejects_mutation uci-batch 'uci -q batch'
assert_policy_rejects_mutation path-qualified-nft '/usr/sbin/nft add rule inet fw4 input accept'
assert_policy_rejects_mutation passwall-reenable "uci -q set passwall2.@global[0].enabled='1'"
assert_policy_rejects_mutation nlbwmon-uci-disable "uci -q set nlbwmon.@nlbwmon[0].enabled='0'"
assert_policy_rejects_mutation harmless-extra 'true'

comment_file="$fixture_root/safe-comments.uci-defaults"
sed -E 's/^exit 0$/exit 0 # port 7681 remains blocked/' "$defaults" > "$comment_file"
printf '%s\n' '# no WAN rule for port 7681' >> "$comment_file"
assert_first_boot_policy "$comment_file" || {
  echo "safety comments must not be treated as executable policy" >&2
  exit 1
}

echo "requested packages and defaults: ok"

[[ -x "$required_packages" ]] || {
  echo "missing required-package helper: .github/scripts/required-packages.sh" >&2
  exit 1
}

common_required_packages=(
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
)
istore_required_packages=(
  luci-app-ttyd
  luci-app-store
  quickstart
  luci-app-quickstart
)

write_expected_required_packages() {
  local variant="$1"

  printf '%s\n' "${common_required_packages[@]}"
  if [[ "$variant" == "istore" ]]; then
    printf '%s\n' "${istore_required_packages[@]}"
  fi
}

assert_required_packages() {
  local variant="$1"
  local config="$repo_root/configs/re-ss-01-${variant}.config"
  local expected="$fixture_root/${variant}-required-packages.expected"
  local actual="$fixture_root/${variant}-required-packages.actual"
  local package

  write_expected_required_packages "$variant" > "$expected"
  "$required_packages" "$variant" > "$actual"
  cmp -s "$actual" "$expected" || {
    echo "$variant required packages must have the exact required order" >&2
    exit 1
  }
  awk 'NF == 0 || seen[$0]++ { exit 1 }' "$actual" || {
    echo "$variant required packages must not contain blank lines or duplicates" >&2
    exit 1
  }
  while IFS= read -r package; do
    grep -Fqx "CONFIG_PACKAGE_${package}=y" "$config" || {
      echo "$variant config missing required package: $package" >&2
      exit 1
    }
  done < "$actual"
}

assert_required_packages argon
assert_required_packages istore

unknown_packages_stdout="$fixture_root/unknown-required-packages.stdout"
unknown_packages_stderr="$fixture_root/unknown-required-packages.stderr"
if "$required_packages" unknown > "$unknown_packages_stdout" 2> "$unknown_packages_stderr"; then
  echo "unknown required-package variant must fail" >&2
  exit 1
fi
[[ "$(< "$unknown_packages_stderr")" == 'unknown required-package variant: unknown' ]] || {
  echo "unknown required-package variant error must be exact" >&2
  exit 1
}
[[ ! -s "$unknown_packages_stdout" ]] || {
  echo "unknown required-package variant must not write package output" >&2
  exit 1
}

echo "required package policy: ok"

feed_script="$repo_root/.github/scripts/add-package-feeds.sh"
argon_feeds="$fixture_root/argon-feeds.conf"
istore_feeds="$fixture_root/istore-feeds.conf"
stale_istore_feeds="$fixture_root/stale-istore-feeds.conf"
duplicate_istore_feeds="$fixture_root/duplicate-istore-feeds.conf"
unknown_feeds="$fixture_root/unknown-feeds.conf"

printf '%s\n' '# test feed configuration' > "$argon_feeds"
printf '%s\n' '# test feed configuration' > "$istore_feeds"
printf '%s\n' '# test feed configuration' > "$unknown_feeds"

bash "$feed_script" "$argon_feeds" argon
bash "$feed_script" "$istore_feeds" istore

common_feed_lines=(
  'src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main'
  'src-git passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git;main'
  'src-git mosdns https://github.com/sbwml/luci-app-mosdns.git;v5'
)
istore_feed_lines=(
  'src-git istore https://github.com/linkease/istore.git;main'
  'src-git nas https://github.com/linkease/nas-packages.git;master'
  'src-git nas_luci https://github.com/linkease/nas-packages-luci.git;main'
)

assert_exact_istore_feeds() {
  local feeds_file="$1"
  local actual_istore_feed_lines
  local expected_istore_feed_lines

  for line in "${istore_feed_lines[@]}"; do
    [[ "$(grep -Fxc "$line" "$feeds_file")" -eq 1 ]] || {
      echo "iStore feed must occur exactly once: $line" >&2
      exit 1
    }
  done

  actual_istore_feed_lines="$(grep -E '^src-git (istore|nas|nas_luci)[[:space:]]' "$feeds_file")"
  expected_istore_feed_lines="$(printf '%s\n' "${istore_feed_lines[@]}")"
  [[ "$actual_istore_feed_lines" == "$expected_istore_feed_lines" ]] || {
    echo "iStore feeds must use the required order and exact definitions" >&2
    exit 1
  }
}

feed_file_mode() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

mode_stub_dir="$fixture_root/mode-stubs"
mkdir "$mode_stub_dir"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\\n" "$MODE_TEST_OS"' \
  > "$mode_stub_dir/uname"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ "$MODE_TEST_OS" == "Darwin" && "$1" == "-f" && "$2" == "%Lp" ]]; then' \
  '  printf "%s\\n" "644"' \
  'elif [[ "$MODE_TEST_OS" == "Linux" && "$1" == "-c" && "$2" == "%a" ]]; then' \
  '  printf "%s\\n" "644"' \
  'elif [[ "$MODE_TEST_OS" == "Linux" && "$1" == "-f" ]]; then' \
  '  printf "%s\\n" "File: $3"' \
  '  exit 1' \
  'else' \
  '  exit 1' \
  'fi' \
  > "$mode_stub_dir/stat"
chmod +x "$mode_stub_dir/uname" "$mode_stub_dir/stat"
mode_test_file="$fixture_root/mode-test-file"
printf '%s\n' '# test file' > "$mode_test_file"

[[ "$(MODE_TEST_OS=Linux PATH="$mode_stub_dir:$PATH" feed_file_mode "$mode_test_file")" == '644' ]] || {
  echo "feed mode helper must use GNU stat for Linux" >&2
  exit 1
}
[[ "$(MODE_TEST_OS=Darwin PATH="$mode_stub_dir:$PATH" feed_file_mode "$mode_test_file")" == '644' ]] || {
  echo "feed mode helper must use BSD stat for Darwin" >&2
  exit 1
}

for feeds_file in "$argon_feeds" "$istore_feeds"; do
  for line in "${common_feed_lines[@]}"; do
    [[ "$(grep -Fxc "$line" "$feeds_file")" -eq 1 ]] || {
      echo "common feed must occur exactly once: $line" >&2
      exit 1
    }
  done
done

if grep -Eq '^src-git (istore|nas|nas_luci)[[:space:]]' "$argon_feeds"; then
  echo "Argon must not include iStore-only feeds" >&2
  exit 1
fi

assert_exact_istore_feeds "$istore_feeds"

printf '%s\n' \
  '# test feed configuration' \
  'src-git istore https://example.invalid/istore.git;legacy' \
  'src-git nas https://example.invalid/nas-packages.git;legacy' \
  'src-git nas_luci https://example.invalid/nas-packages-luci.git;legacy' \
  > "$stale_istore_feeds"
chmod 0644 "$stale_istore_feeds"
bash "$feed_script" "$stale_istore_feeds" istore
assert_exact_istore_feeds "$stale_istore_feeds"
[[ "$(feed_file_mode "$stale_istore_feeds")" == '644' ]] || {
  echo "normalizing iStore feeds must preserve mode 0644" >&2
  exit 1
}

printf '%s\n' '# test feed configuration' "${istore_feed_lines[@]}" "${istore_feed_lines[@]}" > "$duplicate_istore_feeds"
chmod 0600 "$duplicate_istore_feeds"
bash "$feed_script" "$duplicate_istore_feeds" istore
assert_exact_istore_feeds "$duplicate_istore_feeds"
[[ "$(feed_file_mode "$duplicate_istore_feeds")" == '600' ]] || {
  echo "normalizing iStore feeds must preserve mode 0600" >&2
  exit 1
}

cp "$argon_feeds" "$fixture_root/argon-feeds-once.conf"
cp "$istore_feeds" "$fixture_root/istore-feeds-once.conf"
bash "$feed_script" "$argon_feeds" argon
bash "$feed_script" "$istore_feeds" istore
cmp -s "$argon_feeds" "$fixture_root/argon-feeds-once.conf" || {
  echo "Argon feed addition must be idempotent" >&2
  exit 1
}
cmp -s "$istore_feeds" "$fixture_root/istore-feeds-once.conf" || {
  echo "iStore feed addition must be idempotent" >&2
  exit 1
}

cp "$unknown_feeds" "$fixture_root/unknown-feeds-before.conf"
unknown_variant_stderr="$fixture_root/unknown-variant.stderr"
if bash "$feed_script" "$unknown_feeds" unknown 2> "$unknown_variant_stderr"; then
  echo "unknown feed variant must fail" >&2
  exit 1
fi
[[ "$(< "$unknown_variant_stderr")" == 'unknown feed variant: unknown' ]] || {
  echo "unknown feed variant error must be exact" >&2
  exit 1
}
cmp -s "$unknown_feeds" "$fixture_root/unknown-feeds-before.conf" || {
  echo "unknown feed variant must not modify the feed file" >&2
  exit 1
}

echo "variant-specific feeds: ok"

ruby - "$repo_root" <<'RUBY'
require "digest"
require "fileutils"
require "open3"
require "tmpdir"

repo = ARGV.fetch(0)
prepare = File.join(repo, ".github/scripts/prepare-release.sh")
verify = File.join(repo, ".github/scripts/verify-release.sh")
policy = File.join(repo, ".github/scripts/required-packages.sh")
input_prefix = "libwrt-qualcommax-ipq60xx-jdcloud_re-ss-01"
suffixes = %w[-squashfs-factory.bin -squashfs-sysupgrade.bin -initramfs-uImage.itb .manifest]

run = lambda do |success, label, *args|
  output, status = Open3.capture2e("bash", *args)
  abort "#{label}: expected #{success ? 'success' : 'failure'}\n#{output}" unless status.success? == success
  puts "release #{label}: ok"
end
checksums = lambda do |directory|
  names = Dir.children(directory).reject { |name| name == "SHA256SUMS" }.sort
  File.write(File.join(directory, "SHA256SUMS"), names.map { |name|
    "#{Digest::SHA256.file(File.join(directory, name)).hexdigest}  #{name}\n"
  }.join)
end

Dir.mktmpdir("release fixtures ") do |root|
  fixture = lambda do |label, variant = "istore"|
    target = File.join(root, label)
    Dir.mkdir(target)
    FileUtils.cp(Dir.glob(File.join(repo, "tests/fixtures/release/{profiles.json,config.buildinfo}")), target)
    File.binwrite(File.join(target, input_prefix + suffixes[0]), "F" * 65536)
    File.write(File.join(target, input_prefix + suffixes[1]), "sysupgrade fixture\n")
    File.write(File.join(target, input_prefix + suffixes[2]), "initramfs fixture\n")
    packages, status = Open3.capture2e("bash", policy, variant)
    abort "fixture package policy failed" unless status.success?
    File.write(File.join(target, input_prefix + suffixes[3]), packages.lines.map { |package| "#{package.strip} - 1.0\n" }.join)
    target
  end
  source = fixture.call("source")
  output = File.join(root, "published")
  config = "configs/re-ss-01-istore.config"
  version = "0.1.0-beta.1"
  prefix = "jdcloud-re-ss-01-libwrt-istore-v0.1.0-beta.1"
  args = ["istore", version, "source-sha", "builder-sha", config]
  # A different working directory must not change which config gets copied.
  Dir.chdir(root) { run.call(true, "prepare", prepare, source, output, *args) }
  run.call(true, "verify", verify, output, "istore", version)
  expected = (suffixes.map { |suffix| prefix + suffix } + %w[profiles.json build.config BUILD-METADATA.txt SHA256SUMS]).sort
  abort "release file set is not exact" unless Dir.children(output).sort == expected
  suffixes.each do |suffix|
    abort "renaming changed #{suffix}" unless File.binread(File.join(source, input_prefix + suffix)) == File.binread(File.join(output, prefix + suffix))
  end
  abort "wrong config was copied" unless File.binread(File.join(output, "build.config")) == File.binread(File.join(repo, config))
  metadata = File.readlines(File.join(output, "BUILD-METADATA.txt"), chomp: true)
  %W[source_commit=source-sha builder_commit=builder-sha config_file=#{config} variant=istore version=#{version}].each do |record|
    abort "missing or duplicate metadata: #{record}" unless metadata.count(record) == 1
  end
  abort "metadata must contain one key=value record per line" unless metadata.all? { |record| record.match?(/\A[a-z_]+=[^\r\n]+\z/) }
  expected_sums = expected.reject { |name| name == "SHA256SUMS" }.map { |name| "#{Digest::SHA256.file(File.join(output, name)).hexdigest}  #{name}\n" }.join
  abort "checksum list must cover every asset exactly once in sorted order" unless File.read(File.join(output, "SHA256SUMS")) == expected_sums
  again = File.join(root, "again")
  Dir.mkdir(again)
  run.call(true, "deterministic preparation into empty directory", prepare, source, again, *args)
  expected.each { |name| abort "nondeterministic #{name}" unless File.binread(File.join(again, name)) == File.binread(File.join(output, name)) }

  bad_prepare = lambda do |label, modified_args = args, &mutation|
    target = fixture.call(label)
    mutation.call(target) if mutation
    destination = File.join(root, "#{label}-output")
    run.call(false, label, prepare, target, destination, *modified_args)
    abort "failed preparation published partial files: #{label}" if File.exist?(destination)
  end
  bad_prepare.call("unaligned factory") { |target| File.open(File.join(target, input_prefix + suffixes[0]), "a") { |file| file.write("x") } }
  suffixes.each do |suffix|
    bad_prepare.call("missing #{suffix}") { |target| FileUtils.rm(File.join(target, input_prefix + suffix)) }
    bad_prepare.call("duplicate #{suffix}") { |target| FileUtils.cp(File.join(target, input_prefix + suffix), File.join(target, "duplicate-" + input_prefix + suffix)) }
  end
  bad_prepare.call("missing quickstart") { |target| path = File.join(target, input_prefix + ".manifest"); File.write(path, File.readlines(path).reject { |line| line.start_with?("luci-app-quickstart ") }.join) }
  bad_prepare.call("package substring or second field") { |target| path = File.join(target, input_prefix + ".manifest"); File.write(path, File.read(path).sub("luci-app-quickstart - 1.0", "luci-app-quickstart-extra - 1.0\nother - luci-app-quickstart")) }
  bad_prepare.call("wrong device only") { |target| suffixes.each { |suffix| FileUtils.mv(File.join(target, input_prefix + suffix), File.join(target, "libwrt-other_jdcloud_re-ss-01-imposter" + suffix)) } }
  bad_prepare.call("wrong version", ["istore", "9.9.9", "source-sha", "builder-sha", config])
  bad_prepare.call("unknown variant", ["unknown", version, "source-sha", "builder-sha", config])
  bad_prepare.call("wrong config", ["istore", version, "source-sha", "builder-sha", "configs/re-ss-01-argon.config"])
  bad_prepare.call("newline metadata", ["istore", version, "source-sha\nvariant=argon", "builder-sha", config])
  bad_prepare.call("missing argument", args[0...-1])
  bad_prepare.call("extra argument", args + ["extra"])
  %w[profiles.json].each do |name|
    bad_prepare.call("missing #{name}") { |target| FileUtils.rm(File.join(target, name)) }
  end
  bad_prepare.call("empty image") { |target| File.write(File.join(target, input_prefix + suffixes[0]), "") }
  # Neighbouring-device assets in the build tree must never reach the release.
  File.write(File.join(source, "libwrt-redmi_ax5-jdcloud-squashfs-factory.bin"), "other device")
  isolated = File.join(root, "isolated")
  run.call(true, "device isolation", prepare, source, isolated, *args)
  abort "another device was copied" unless Dir.children(isolated).sort == expected
  sentinel = File.join(output, "keep.txt")
  File.write(sentinel, "existing user data")
  run.call(false, "nonempty output", prepare, source, output, *args)
  abort "existing output was changed" unless File.read(sentinel) == "existing user data"
  FileUtils.rm(sentinel)

  bad_verify = lambda do |label, rehash = true, &mutation|
    directory = File.join(root, "verify #{label}")
    FileUtils.cp_r(output, directory)
    mutation.call(directory)
    checksums.call(directory) if rehash
    run.call(false, label, verify, directory, "istore", version)
  end
  bad_verify.call("checksum mismatch", false) { |directory| File.write(File.join(directory, prefix + suffixes[1]), "corrupted") }
  bad_verify.call("unaligned verification") { |directory| File.open(File.join(directory, prefix + suffixes[0]), "a") { |file| file.write("x") } }
  bad_verify.call("first field verification") { |directory| path = File.join(directory, prefix + ".manifest"); File.write(path, File.read(path).sub("luci-app-quickstart - 1.0", "luci-app-quickstart-extra - 1.0\nother - luci-app-quickstart")) }
  %w[jdcloud-re-cp-03-libwrt-istore-v0.1.0-beta.1-squashfs-factory.bin jdcloud-re-ss-01-libwrt-argon-v1.0.0-squashfs-factory.bin].each do |name|
    bad_verify.call("foreign #{name}") { |directory| File.write(File.join(directory, name), "foreign") }
  end
  expected.each do |name|
    bad_verify.call("missing release #{name}", name != "SHA256SUMS") { |directory| FileUtils.rm(File.join(directory, name)) }
    bad_verify.call("empty release #{name}", name != "SHA256SUMS") { |directory| File.write(File.join(directory, name), "") }
  end
  bad_verify.call("incomplete checksum coverage", false) { |directory| path = File.join(directory, "SHA256SUMS"); File.write(path, File.readlines(path)[0...-1].join) }
  bad_verify.call("duplicate checksum entry", false) { |directory| path = File.join(directory, "SHA256SUMS"); File.open(path, "a") { |file| file.write(File.readlines(path).first) } }
  bad_verify.call("metadata variant mismatch") { |directory| path = File.join(directory, "BUILD-METADATA.txt"); File.write(path, File.read(path).sub("variant=istore", "variant=argon")) }
  run.call(false, "verify wrong version", verify, output, "istore", "9.9.9")
  run.call(false, "verify extra argument", verify, output, "istore", version, "extra")
  argon = fixture.call("argon source", "argon")
  argon_output = File.join(root, "argon output")
  run.call(true, "Argon preparation", prepare, argon, argon_output, "argon", "1.0.0", "source-sha", "builder-sha", "configs/re-ss-01-argon.config")
  run.call(true, "Argon verification", verify, argon_output, "argon", "1.0.0")
end
puts "release collection and verification: ok"
RUBY
