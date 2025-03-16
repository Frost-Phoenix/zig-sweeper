# treefmt.nix
{ ... }:
{
  # Used to find the project root
  projectRootFile = "flake.nix";

  settings.global.excludes = [
    "*.md"
    "*.png"
    "*.lock"
    "*.zon2json-lock"
    "LICENSE"
  ];

  programs = {
    nixfmt.enable = true;
    zig.enable = true;
  };

  settings.formatter = {
    nixfmt.options = [
      "-sv"
      "-w"
      "80"
    ];
  };
}
