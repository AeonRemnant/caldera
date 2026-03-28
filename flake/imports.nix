{ inputs, ... }:
{
  imports = [
    inputs.treefmt-nix.flakeModule
    inputs.git-hooks-nix.flakeModule
    ./system.nix
    ./installer.nix
    ./treefmt.nix
    ./git-hooks.nix
  ];
}
