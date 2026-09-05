# Release fixtures

`tests/test-builder.sh` creates the firmware files in temporary directories:
the factory is exactly 65536 bytes, the other images contain distinct markers,
and the manifest lists every package returned by `required-packages.sh` for the
selected variant. These are synthetic test data, never flashable firmware.

The adjacent `profiles.json` and `config.buildinfo` represent the build's
auxiliary files. Release `build.config` must come from the selected repository
config, not from this deliberately minimal `config.buildinfo`.
