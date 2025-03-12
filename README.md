# 🚀 Setup Vlang GitHub Action

## 📌 Description

This GitHub Action installs **Vlang** in a specified directory using a simple script.
It supports version management, stable releases,
and multiple architectures (Linux/WSL, macOS, Windows, Windows).

## 🧑‍💻 Usage

Add this action to your GitHub workflow:

```yaml
name: Set up Vlang environment

on: ['push', 'pull_request']

jobs:
  setup:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup V
        uses: @siguici/setup-v@v1
        with:
          install: true
          path: $HOME/v

      - name: Verify V Installation
        run: v version
```

## 🔧 Inputs

| Name | Description | Default |
|------|------------|--------|
| `update` | Update V after installation | `false` |
| `install` | Install V dependencies | `false` |
| `cwd`    | Directory in which to execute the commands | `.` |
| `path` | Installation path for Vlang | `${{ runner.temp }}/v` |
| `token` | Personal access token (PAT) for fetching the repository | `${{ github.token }}` |
| `version` | Specific V version to install (tag, branch, SHA) | `master` |
| `version-file` | File containing the version to install | `''` |
| `latest` | Check for the latest available version | `false` |
| `stable` | Install the latest stable version | `false` |
| `architecture` | Target architecture (`linux`, `macos`, `windows`) | Auto-detected |

## 📤 Outputs

| Name | Description |
|------|------------|
| `bin-path` | Path to the directory containing the V binary |
| `v-bin-path` | Direct path to the V binary |
| `version` | Installed V version |
| `architecture` | Architecture used for installation |

## 💡 Examples

Here is a complete example for a CI workflow that tests across multiple OS platforms:

```yaml
name: CI

on: ['push', 'pull_request']

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    name: 👷 CI Vlang on ${{ matrix.os }}

    timeout-minutes: 60

    steps:
      - name: 🚚 Checkout repository
        uses: actions/checkout@v4

      - name: Setup V
        uses: @siguici/setup-v@v1
        with:
          cwd: packages/v-project
          path: $HOME/v
          install: true
          version-file: .v-version
          latest: true

      - name: Show Installed Version
        run: v version
```

## 📜 License

Under the [MIT License](./LICENSE.md).
Created with ❤️ by [Sigui Kessé Emmanuel](https://github.com/siguici).
