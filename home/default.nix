{ config, pkgs, lib, inputs, userConfig, ... }:

let
  availableBrowsers = {
    firefox = pkgs.firefox;
    brave = pkgs.brave;
  };

  browsersToInstall = lib.filter (name: name != "firefox") userConfig.browsers;
  browserPackages = map (browserName: availableBrowsers.${browserName}) browsersToInstall;

in
{
  home.stateVersion = "25.05";

  home.username = userConfig.username;
  home.homeDirectory = "/home/${userConfig.username}";

  imports = [
    ./zsh
  ] ++ lib.optionals (builtins.elem "firefox" userConfig.browsers) [
    ./firefox 
  ];

  home.packages = [
    pkgs.eza
  ] ++ browserPackages;

  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Amber";
    size = 24;
  };

  home.sessionVariables = {
    EDITOR = "nvim"; 
    VISUAL = "nvim";
  };

  home.sessionPath = [
    "$HOME/go/bin"
  ];
}
