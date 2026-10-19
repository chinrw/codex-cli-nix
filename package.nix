{ lib
, stdenv
, fetchurl
, makeWrapper
, gnutar
, gzip
, zstd
, openssl
, libcap
, libz
, bubblewrap
, binName ? "codex"
}:

let
  version = "0.163.0";

  platformMap = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or
    (throw "Codex is not supported on ${stdenv.hostPlatform.system}. Supported: aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux");

  # Daemon bootstrap copies this complete package, including its manifest.
  nativeHashes = {
    "aarch64-apple-darwin" = "0b20ndp3g8lg38bga5v5r80ns764icg6165zx81k0phiavljx084";
    "x86_64-apple-darwin" = "0f3yva2myxxhzw4wkn025lznw4921ma8ki8lr074q308ysigrxjz";
    "x86_64-unknown-linux-musl" = "15lwrxj99m5bgwj58xdsd9cal75ygw317cg82zl2fyabyb0xl8nz";
    "aarch64-unknown-linux-musl" = "1sb0haqzbw04rm80bwr349ip8gvgvbdifp3biyyxzdf4lh0vk57v";
  };

  nativeBinary = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-${platform}.tar.zst";
    sha256 = nativeHashes.${platform};
  };

  # The bundled ARM64 Linux rg requires a glibc loader. Use a static archive
  # so the daemon's copied package also survives Nix store garbage collection.
  useStaticRg = stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isAarch64;
  staticRgVersion = "15.2.0";
  staticRgName = "ripgrep-${staticRgVersion}-aarch64-unknown-linux-musl";
  staticRg = fetchurl {
    url = "https://github.com/BurntSushi/ripgrep/releases/download/${staticRgVersion}/${staticRgName}.tar.gz";
    sha256 = "0589fkhqc7pn020m6412wphapykw2hiiz456npgrkrxg0rr1w2w0";
  };

  linuxRuntimePath = lib.makeBinPath (lib.optionals stdenv.isLinux [ bubblewrap ]);
in
stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  dontUnpack = true;
  dontPatchELF = true;
  dontStrip = true;

  nativeBuildInputs = [ gnutar gzip zstd makeWrapper ];
  buildInputs = lib.optionals stdenv.isLinux [ openssl libcap libz ];

  buildPhase = ''
    runHook preBuild
    mkdir -p build
    tar --zstd -xf ${nativeBinary} -C build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib

    # Codex discovers its package from bin/ and the adjacent manifest.
    cp -r build $out/lib/codex
    ${lib.optionalString useStaticRg ''
      rm $out/lib/codex/codex-path/rg
      tar -xzf ${staticRg} --strip-components=1 \
        -C $out/lib/codex/codex-path ${staticRgName}/rg
      mkdir -p $out/share/licenses/ripgrep
      tar -xzf ${staticRg} --strip-components=1 \
        -C $out/share/licenses/ripgrep \
        ${staticRgName}/COPYING ${staticRgName}/LICENSE-MIT ${staticRgName}/UNLICENSE
    ''}

    ln -s ../lib/codex/bin/codex-code-mode-host $out/bin/codex-code-mode-host
    makeWrapper "$out/lib/codex/bin/codex" "$out/bin/${binName}" \
      --run 'export CODEX_EXECUTABLE_PATH="$HOME/.local/bin/${binName}"' \
      --set DISABLE_AUTOUPDATER 1 \
      ${lib.optionalString stdenv.hostPlatform.isLinux ''--prefix PATH : "${linuxRuntimePath}"''}
    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenAI Codex CLI (Native Binary) - AI coding assistant in your terminal";
    homepage = "https://github.com/openai/codex";
    license = licenses.asl20;
    platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
    mainProgram = binName;
  };
}
