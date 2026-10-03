# Canon MG2500-only driver

Canon 4.00 driver for the MG2500 series, including the MG2522. Builds one
`cifmg2500` filter instead of eight model variants. Installs only model 429's
database and libraries, its PPD, the shared print/maintenance filters, and USB
backends. Omits network backends and Canon's desktop utilities. Compilation
uses Nix's available build cores.

The source and compatibility patches come from `pkgs.cnijfilter_4_00`; this
does **not** depend on building that package. The standalone flake is locked to
the nixpkgs revision used for verification.

```sh
nix build github:jaycee1285/cnijfilter-flake -L
```

## NixOS use

In your system flake:

```nix
inputs.cnijfilter-flake.url = "github:jaycee1285/cnijfilter-flake";
inputs.cnijfilter-flake.inputs.nixpkgs.follows = "nixpkgs";
```

Include `cnijfilter-flake` in the `outputs` argument and add
`cnijfilter-flake.overlays.default` to your system's nixpkgs overlays.
In `modules/services.nix`:

```nix
services.printing.drivers = [
  pkgs.cnijfilter-mg2500
];
```

This uses your system's `pkgs`. Set `nixpkgs.config.allowUnfree = true` to
permit Canon's binary libraries. Existing MG2500 PPD and filter names are
preserved. To update the driver commit in your configuration's lockfile:

```sh
nix flake update cnijfilter-flake
```

The filter must use `/var/lib/cups/path/lib/bjlib`, the short driver-union path
provided by NixOS. Canon's binary library truncates a direct Nix store path
when loading its tables, emitting job headers without rendered page data.
Keep the short path even though the tables are installed into the package.

An unchanged derivation is reused by Nix on subsequent rebuilds. Updating
nixpkgs can change its compiler or library inputs and require recompilation.
This driver reduces the work when that happens; it does not prevent rebuilding
changed inputs. Ghostscript remains required for the PostScript rendering path.

Original implementation:
[nixpkgs cnijfilter_4_00](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/cn/cnijfilter_4_00/package.nix).

Physical printing must be checked on the MG2522 after switching. The tested
configuration uses CUPS' `usb://` backend.

## Verification (2026-10-03)

- Build: approximately 54 seconds with dependencies already present.
- Installed package: 1.6 MB, versus 12 MB for the previous all-model package.
- A one-page PostScript job rendered to 26,775 bytes of printer data, identical
  to the installed all-model driver's output in the same run.
- All packaged executables and shared libraries resolve their ELF dependencies.
- Rechecked after reboot: render comparison still passes; Sed's printing config
  evaluates to the same built MG2500 derivation.
- Physical printing: pending human verification.
