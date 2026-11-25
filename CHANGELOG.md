# Changelog

## [0.1.0-beta.6](https://github.com/YangJonghun/rex-agent-resume/compare/v0.1.0-beta.5...v0.1.0-beta.6) (2026-11-25)


### Features

* add a palette action to restore approval-skipping modes ([e9f77c8](https://github.com/YangJonghun/rex-agent-resume/commit/e9f77c8002829ba00059c34d74ecc9160097c668))
* restore the options agents forget on resume, read from their transcripts ([809131a](https://github.com/YangJonghun/rex-agent-resume/commit/809131a556701c2f397d89efd6b5217543611690))
* restore the options agents were started with but forget on resume ([3ef12f3](https://github.com/YangJonghun/rex-agent-resume/commit/3ef12f3c1cb39ff6339f1452aeef6021b90aaa69))


### Bug Fixes

* install the cursor hook in ~/.cursor whatever its config dir ([6b9bde6](https://github.com/YangJonghun/rex-agent-resume/commit/6b9bde6f82f8ae7c60b6338ccff3f5ca46de5b8f))
* install the grok hook under GROK_HOME only ([c1e452e](https://github.com/YangJonghun/rex-agent-resume/commit/c1e452e1dce6ae5a872b90e902ee7f6041fca557))
* resume mastracode threads with `mastracode resume <id>` ([cb29c46](https://github.com/YangJonghun/rex-agent-resume/commit/cb29c4670d14679e3ba09381fde36f9ff5d92ffa))

## [0.1.0-beta.5](https://github.com/YangJonghun/rex-agent-resume/compare/v0.1.0-beta.4...v0.1.0-beta.5) (2026-11-06)


### Bug Fixes

* save the snapshot as soon as a hook records a session ([97f8ecc](https://github.com/YangJonghun/rex-agent-resume/commit/97f8ecc4e35d48f5373960dd16d12ebac7d5c089))

## [0.1.0-beta.4](https://github.com/YangJonghun/rex-agent-resume/compare/v0.1.0-beta.3...v0.1.0-beta.4) (2026-11-06)


### Bug Fixes

* clear text typed in a pane before typing its resume line ([78c390e](https://github.com/YangJonghun/rex-agent-resume/commit/78c390e3ab13393b059e88f48de469d3c767d704))

## [0.1.0-beta.3](https://github.com/YangJonghun/rex-agent-resume/compare/v0.1.0-beta.2...v0.1.0-beta.3) (2026-11-04)


### Bug Fixes

* let a new server's watcher take over from one whose server died ([9118a04](https://github.com/YangJonghun/rex-agent-resume/commit/9118a043e48bd27eadf16469d3a918d2fdc7c1ed))

## [0.1.0-beta.2](https://github.com/YangJonghun/rex-agent-resume/compare/v0.1.0-beta.1...v0.1.0-beta.2) (2026-11-03)


### Bug Fixes

* keep an empty Codex config.toml the user had when uninstalling ([95324c7](https://github.com/YangJonghun/rex-agent-resume/commit/95324c7f101ee6dd44ad4f6b327ae00d101709c7))
* leave no files behind when uninstalling ([bb5d68b](https://github.com/YangJonghun/rex-agent-resume/commit/bb5d68b6bf0587b81280c329bc41b33fe7f8306b))

## [0.1.0-beta.1](https://github.com/YangJonghun/rex-agent-resume/compare/v0.1.0-beta.0...v0.1.0-beta.1) (2026-11-03)


### Features

* add installer, uninstaller, and Rex plugin entry point ([bd3d188](https://github.com/YangJonghun/rex-agent-resume/commit/bd3d188176c6572ab2513f0213cd4b3b73410541))
* add per-agent resume rules and process detection ported from herdr ([692e53d](https://github.com/YangJonghun/rex-agent-resume/commit/692e53dd759e2cce1349a678e914bf562a75bce8))
* record agent sessions from hooks and plugins ([da13dd8](https://github.com/YangJonghun/rex-agent-resume/commit/da13dd8d79a2e1942705c3c440bd62deffbf8081))
* snapshot panes and resume agents after a server restart ([a2f642b](https://github.com/YangJonghun/rex-agent-resume/commit/a2f642b37aab6f63f1e72374d4ba4284a44d4654))
