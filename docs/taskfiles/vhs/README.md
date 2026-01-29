---
title: "VHS Tasks"
description: "Terminal session recording and GIF generation tasks using VHS (Video-to-Hardcopy-Software)"
---
# VHS Tasks (`vhs:`)

Generate GIF animations from terminal session recordings using VHS (Video-to-Hardcopy-Software).

## Overview

The `vhs:` namespace provides tools for generating animated GIFs from terminal session recordings. These tasks are used to create documentation animations showing command-line workflows. VHS reads `.tape` files (which contain terminal commands and expected output) and generates GIF animations.

## Task Reference

| Task | Description |
|------|-------------|
| [`make-windsor-init-gif`](#make-windsor-init-gif) | Build Windsor init GIF animation |
| [`make-windsor-up-gif`](#make-windsor-up-gif) | Build Windsor up GIF animation |
| [`make-port-forwarding-gif`](#make-port-forwarding-gif) | Build port forwarding GIF animation |
| [`make-windsor-down-gif`](#make-windsor-down-gif) | Build Windsor down GIF animation |
| [`make-check-ha-pod-gif`](#make-check-ha-pod-gif) | Build check HA pod GIF animation |

## GIF Generation Tasks

### `make-windsor-init-gif`

Build Windsor init GIF animation.

**Usage:**

```bash
task vhs:make-windsor-init-gif
```

**What it does:**

1. Reads VHS tape file: `docs/img/vhs/windsor-init.tape`
2. Generates GIF: `docs/img/windsor-init.gif`

**Example:**

```bash
task vhs:make-windsor-init-gif
```

### `make-windsor-up-gif`

Build Windsor up GIF animation.

**Usage:**

```bash
task vhs:make-windsor-up-gif
```

**What it does:**

1. Reads VHS tape file: `docs/img/vhs/windsor-up.tape`
2. Generates GIF: `docs/img/windsor-up.gif`

**Example:**

```bash
task vhs:make-windsor-up-gif
```

### `make-port-forwarding-gif`

Build port forwarding GIF animation.

**Usage:**

```bash
task vhs:make-port-forwarding-gif
```

**What it does:**

1. Reads VHS tape file: `docs/img/vhs/port-forwarding.tape`
2. Generates GIF: `docs/img/port-forwarding.gif`

**Example:**

```bash
task vhs:make-port-forwarding-gif
```

### `make-windsor-down-gif`

Build Windsor down GIF animation.

**Usage:**

```bash
task vhs:make-windsor-down-gif
```

**What it does:**

1. Reads VHS tape file: `docs/img/vhs/windsor-down.tape`
2. Generates GIF: `docs/img/windsor-down.gif`

**Example:**

```bash
task vhs:make-windsor-down-gif
```

### `make-check-ha-pod-gif`

Build check HA pod GIF animation.

**Usage:**

```bash
task vhs:make-check-ha-pod-gif
```

**What it does:**

1. Reads VHS tape file: `docs/img/vhs/check-ha-pod.tape`
2. Generates GIF: `docs/img/check-ha-pod.gif`

**Example:**

```bash
task vhs:make-check-ha-pod-gif
```

## How VHS Works

VHS reads `.tape` files that contain:

1. **Terminal setup commands** - Configure terminal appearance, size, theme
2. **Command execution** - Run commands and wait for output
3. **Type commands** - Simulate typing
4. **Wait for output** - Wait for specific text to appear
5. **Screenshots** - Capture frames at specific points
6. **GIF generation** - Combine frames into animated GIF

**Example VHS tape file:**

```tape
Output docs/img/windsor-init.gif
Set FontSize 14
Set Width 800
Set Height 600

Type "windsor init"
Sleep 1s
```

## Prerequisites

- VHS installed: `brew install vhs` (macOS) or download from [VHS releases](https://github.com/charmbracelet/vhs/releases)
- VHS tape files exist in `docs/img/vhs/`
- Output directory exists: `docs/img/`

## Creating New GIF Animations

To create a new GIF animation:

1. Create a `.tape` file in `docs/img/vhs/`
2. Add a new task to `tasks/vhs/Taskfile.yaml`
3. Run the task to generate the GIF

**Example task definition:**

```yaml
make-my-gif:
  desc: Builds my custom GIF
  cmds:
    - vhs docs/img/vhs/my-animation.tape -o docs/img/my-animation.gif
```

## Help

View all available VHS commands:

```bash
task vhs:help
```

## Additional Resources

- [VHS Documentation](https://pkg.go.dev/github.com/charmbracelet/vhs#readme-tutorial)
- [VHS GitHub Repository](https://github.com/charmbracelet/vhs)

## Taskfile Location

Task definitions are located in `tasks/vhs/Taskfile.yaml`.
