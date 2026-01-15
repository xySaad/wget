## Overview

A wget implementation in [zig](https://ziglang.org/), supports only HTTP for now.

## Instalation

to build and run in one command:

```bash
zig build run -- https://ftp.gnu.org/gnu/wget/wget-latest.tar.gz
```

build:

```bash
zig build
```

run:

```bash
./zig-out/bin/wget https://ftp.gnu.org/gnu/wget/wget-latest.tar.gz
```
