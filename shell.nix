{ pkgs ? (import <nixpkgs> {}), ... }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    crystal
    shards
    ncurses
    readline
    glibc
    fswatch
  ];
}

