{ lib, stdenv, cnijfilter_4_00, autoconf, automake, libtool, cups, popt,
  ghostscript, glib, libusb1, libxml2 }:

let
  arch = if stdenv.hostPlatform.system == "x86_64-linux" then "64"
    else if stdenv.hostPlatform.system == "i686-linux" then "32"
    else throw "Canon MG2500 binaries require x86 Linux";
  components = "libs pstocanonij cmdtocanonij backend cnijbe lgmon2 cnijfilter";
in
stdenv.mkDerivation {
  pname = "cnijfilter-mg2500";
  version = "4.00";
  # Reuse Canon's source and nixpkgs compatibility patches, without building
  # the all-model driver derivation.
  inherit (cnijfilter_4_00) src patches;
  nativeBuildInputs = [ autoconf automake libtool ];
  buildInputs = [ cups popt glib libusb1 libxml2 ];
  env.NIX_CFLAGS_COMPILE = "-std=gnu90";
  enableParallelBuilding = true;

  postPatch = ''
    substituteInPlace backend/src/Makefile.am cnijbe/src/Makefile.am \
      --replace-fail /usr/lib/cups/backend "$out/lib/cups/backend"
    substituteInPlace backend/src/cnij_backend_common.c \
      --replace-fail /usr "$out"
    substituteInPlace pstocanonij/filter/pstocanonij.c \
      --replace-fail /usr/bin "${ghostscript}/bin"
    substituteInPlace lgmon2/src/Makefile.am \
      --replace-fail /usr/include/libusb-1.0 "${libusb1.dev}/include/libusb-1.0" \
      --replace-fail 'cnijlgmon2_LDADD =' 'cnijlgmon2_LDADD = -L../../com/libs_bin${arch}'
  '';

  configurePhase = ''
    runHook preConfigure
    export NIX_LDFLAGS="$NIX_LDFLAGS -rpath $out/lib"
    for component in ${components}; do
      flags=(--prefix="$out")
      case "$component" in
        pstocanonij|cnijbe|lgmon2) flags+=(--enable-progpath="$out/bin");;
        cmdtocanonij) flags+=(--datadir="$out/share");;
        # Canon's binary library truncates long table paths. Use the short
        # driver-union path maintained by the NixOS printing module.
        cnijfilter) flags+=(--program-suffix=mg2500 --enable-libpath=/var/lib/cups/path/lib/bjlib --enable-binpath="$out/bin");;
      esac
      if [ "$component" = lgmon2 ]; then
        flags+=(--enable-libpath="$out/lib/bjlib")
      fi
      (cd "$component"; ./autogen.sh "''${flags[@]}")
    done
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    for component in ${components}; do
      make -C "$component" -j"$NIX_BUILD_CORES"
    done
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/lib/cups/filter" "$out/share/cups/model" "$out/lib/bjlib"
    for component in ${components}; do
      make -C "$component" install
    done
    install -m644 ppd/canonmg2500.ppd "$out/share/cups/model/"
    install -m644 429/database/* "$out/lib/bjlib/"
    install -m755 429/libs_bin${arch}/*.so.* com/libs_bin${arch}/*.so.* "$out/lib/"
    for so_file in "$out"/lib/*.so.*; do
      name=$(basename "$so_file")
      ln -s "$name" "$out/lib/''${name%%.so.*}.so"
      # Canon libraries use dlopen, so retain this RPATH during fixup.
      patchelf --set-rpath "$out/lib:${lib.makeLibraryPath [ stdenv.cc.libc ]}" "$so_file"
    done
    runHook postInstall
  '';
  dontPatchELF = true;
  meta = {
    description = "Canon MG2500 series (including MG2522) USB printer driver";
    inherit (cnijfilter_4_00.meta) homepage license sourceProvenance;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
