{ lib
, stdenv
, fetchurl
, makeWrapper
, gnutar
, gzip
, openssl
, libcap
, libz
, bubblewrap
, binName ? "codex"
}:

let
  version = "0.148.0";

  platformMap = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or
    (throw "Codex is not supported on ${stdenv.hostPlatform.system}. Supported: aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux");

  nativeHashes = {
    "aarch64-apple-darwin" = "0azw53j67vxfrqf9rbpg85pyv9zipvy30205d83sv9zg72m1d2bm";
    "x86_64-apple-darwin" = "0fhsvbh4k1905sb3wnbip8lr5cnarskdvd0p5y01y9s2y9r1fnal";
    "x86_64-unknown-linux-musl" = "0npfrz98kjpj1hjnm6ak9pcc4qbna7cmld46pcrzbgmkyrigfdhs";
    "aarch64-unknown-linux-musl" = "1b3mn5ycjydpx3w82gb6xvk9hjmaz5imwrhpvb33ksv3qzh6l321";
  };

  # codex >= 0.143 spawns a separate `codex-code-mode-host` binary (found
  # next to the running executable) when "code mode" is enabled. Shipped as its
  # own release asset, so the native build must fetch and install it too.
  codeModeHostHashes = {
    "aarch64-apple-darwin" = "0d2y7cprd0fv5nymlmblcs3h2vrbygc9qq7v2ygipvpgxiigbshh";
    "x86_64-apple-darwin" = "0l6shks5mjydi3n0langcgayl3fd6q7cnwnimrihpijlhrp5rbd2";
    "x86_64-unknown-linux-musl" = "0acqsncr9iv3rw03zkmw4l87as10q0gc6a1czcc1p9lg4admavlf";
    "aarch64-unknown-linux-musl" = "190kfp7j9dpdn9afnx2qbmvv8bsin58c21gykrj4jj8ppgj0yh8w";
  };

  nativeBinary = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-${platform}.tar.gz";
    sha256 = nativeHashes.${platform};
  };

  codeModeHost = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-code-mode-host-${platform}.tar.gz";
    sha256 = codeModeHostHashes.${platform};
  };

  linuxRuntimePath = lib.makeBinPath (lib.optionals stdenv.isLinux [ bubblewrap ]);
in
stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  dontUnpack = true;
  dontPatchELF = true;
  dontStrip = true;

  nativeBuildInputs = [ gnutar gzip makeWrapper ];
  buildInputs = lib.optionals stdenv.isLinux [ openssl libcap libz ];

  buildPhase = ''
    runHook preBuild
    mkdir -p build
    tar -xzf ${nativeBinary} -C build
    mv build/codex-${platform} build/codex
    chmod u+w,+x build/codex

    tar -xzf ${codeModeHost} -C build
    mv build/codex-code-mode-host-${platform} build/codex-code-mode-host
    chmod u+w,+x build/codex-code-mode-host

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    cp build/codex $out/bin/codex-raw
    chmod +x $out/bin/codex-raw
    cp build/codex-code-mode-host $out/bin/codex-code-mode-host
    chmod +x $out/bin/codex-code-mode-host
    makeWrapper "$out/bin/codex-raw" "$out/bin/${binName}" \
      --run 'export CODEX_EXECUTABLE_PATH="$HOME/.local/bin/${binName}"' \
      --set DISABLE_AUTOUPDATER 1 \
      ${lib.optionalString stdenv.isLinux ''--prefix PATH : "${linuxRuntimePath}"''}
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
