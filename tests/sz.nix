{ lib }:
import ./gz.nix {
  inherit lib;
  host = "sz";
}
