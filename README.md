[![Zig](https://img.shields.io/badge/-Zig-F7A41D?style=flat&logo=zig&logoColor=white)](https://ziglang.org/) ⚡

# tree-command

tree-command is a Utility to display tree view of directories, written in zig.

## Features
 - Display tree view of current directory
 - Customize tree view parameters
 - Support for unicode icons
 - Supply multiple directories for display
 - Command-line argument parsing with zig-clap

## Installation

To install tree-command, you'll need to have Zig `0.13.0` on your system. Then, follow these steps:

1. Clone the repository:
   ```
   git clone https://github.com/JustinBraben/tree-command.git
   cd tree-command
   ```

2. Build the project:
   ```
   zig build
   ```

3. Run tree-command:
   ```
   zig build run
   ```

## Usage

Basic usage:

```
zig build run
```

For more options, use the `-h` flag:

```
zig build run -- -h
```

To display directories only:

```
zig build run -- -d
```

To display all files:

```
zig build run -- -a
```

To many directories sequentially:

```
zig build run -- ./src/ ./zig-out/
```

## Dependencies

- [zig-clap](https://github.com/Hejsil/zig-clap): A command-line argument parser for Zig

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgements

- Built with [Zig](https://ziglang.org/)

## TODO

- [x] Display tree view
- [x] Display unicode characters
- [x] Display directories only `-d`
- [x] Display all files `-a`
- [x] Display in reverse `-r`
- [x] Display positionals sequentially `<DIR>...`
- [ ] Display with full path name `-f`
- [ ] Display with max Depth `-L <USIZE>`