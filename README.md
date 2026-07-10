# git-auto-check

A CLI that automatically runs your checks before you push.

## Installation

Supports Linux and macOS

### Manual

The CLI is a bash script that only depends on `git` so you can just download it
and make it executable by running `chmod +x <path_to_script>`.

### Nix (flake)

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    git-auto-check = {
      url = "github:bigolu/git-auto-check";
      inputs = {
        nixpkgs.follows = "nixpkgs";

        # Remove development dependencies
        devshell.follows = "";
        flake-compat.follows = "";
        devshell-modules.follows = "";
      };
    };
  };

  outputs = inputs:
    let
      # You can use the package
      package = inputs.git-auto-check.packages.${system}.default;
      # Or the overlay
      packageFromOverlay = (import inputs.nixpkgs { overlays = [inputs.git-auto-check.overlays.default]; }).git-auto-check;
    in
    {
      # ...
    }
}
```

## Usage

### Setting up the git hooks

Run the following command:

```bash
git-auto-check install <check_command>...
```

Where `check_command` is the command that does the checking.

Example: `git-auto-check install cargo test`

### Caching

Clear the cache with `git-auto-check cache clear`.

During an interactive rebase you can manually add a cache entry with `git-auto-check cache add`.

