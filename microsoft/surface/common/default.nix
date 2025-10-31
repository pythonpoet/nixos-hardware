{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkDefault
    mkOption
    types
    versions
    ;

  # Set the version and hash for the kernel sources
  srcVersion =
    with config.hardware.microsoft-surface;
    if kernelVersion == "longterm" then
      "6.15.9"
    else if kernelVersion == "stable" then
      "6.16.9"
    else
      abort "Invalid kernel version: ${kernelVersion}";

  srcHash =
    with config.hardware.microsoft-surface;
    if kernelVersion == "longterm" then
      "sha256-6U86+FSSMC96gZRBRY+AvKCtmRLlpMg8aZ/zxjxSlX0="
    else if kernelVersion == "stable" then
      "sha256-esjIo88FR2N13qqoXfzuCVqCb/5Ve0N/Q3dPw7ZM5Y0="
    else
      abort "Invalid kernel version: ${kernelVersion}";

  # Set the version and hash for the linux-surface releases
  pkgVersion =
    with config.hardware.microsoft-surface;
    if kernelVersion == "longterm" then
      "6.12.7"
    else if kernelVersion == "stable" then
      "6.16.9"
    else
      abort "Invalid kernel version: ${kernelVersion}";

  pkgHash =
    with config.hardware.microsoft-surface;
    if kernelVersion == "longterm" then
      "sha256-Pv7O8D8ma+MPLhYP3HSGQki+Yczp8b7d63qMb6l4+mY="
    else if kernelVersion == "stable" then
      "sha256-2h+0oC8IBs3q2e7B1Ms2egYc0H5INAcCFRkFtB1sf5E="
    else
      abort "Invalid kernel version: ${kernelVersion}";

  # Fetch the linux-surface package
  repos =
    pkgs.callPackage
      (
        {
          fetchFromGitHub,
          rev,
          hash,
        }:
        {
          linux-surface = fetchFromGitHub {
            owner = "linux-surface";
            repo = "linux-surface";
            rev = rev;
            hash = hash;
          };
        }
      )
      {
        hash = pkgHash;
        rev = "arch-${pkgVersion}-1";
      };

  # Fetch and build the kernel package
  inherit (pkgs.callPackage ./kernel/linux-package.nix { inherit repos; })
    linuxPackage
    surfacePatches
    ;
  kernelPatches = surfacePatches {
    version = pkgVersion;
    patchFn = ./kernel/${versions.majorMinor pkgVersion}/patches.nix;
    patchSrc = (repos.linux-surface + "/patches/${versions.majorMinor pkgVersion}");
  };
  kernelPackages = linuxPackage {
    inherit kernelPatches;
    version = srcVersion;
    sha256 = srcHash;
    ignoreConfigErrors = true;
  };

in
{
  options.hardware.microsoft-surface.kernelVersion = mkOption {
    description = "Kernel Version to use (patched for MS Surface)";
    type = types.enum [
      "longterm"
      "stable"
    ];
    default = "longterm";
  };

  config = {
    boot = {
      inherit kernelPackages;

      # Seems to be required to properly enable S0ix "Modern Standby":
      kernelParams = mkDefault [ "mem_sleep_default=deep" ];
    };

    # NOTE: Check the README before enabling TLP:
    services.tlp.enable = mkDefault false;

    # Needed for wifi firmware, see https://github.com/NixOS/nixos-hardware/issues/364
    hardware = {
      enableRedistributableFirmware = mkDefault true;
      sensor.iio.enable = mkDefault true;
    };
  };
}
