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
  version = "0.150.1";

  platformMap = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or
    (throw "Codex is not supported on ${stdenv.hostPlatform.system}. Supported: aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux");

  nativeHashes = {
    "aarch64-apple-darwin" = "1dn7dxh64hp47vr2746d2f4hq6qj4kpgm1pgi9m9v97dy52iqvzn";
    "x86_64-apple-darwin" = "1anhs4s0kk59gynci3y359vha55bh6v1cjdy7ys45jy22fqxw2yh";
    "x86_64-unknown-linux-musl" = "0yjw2n87mgl8cqnqinmrk7yfg75gp3v077f47p14ih3zpiq8hc5b";
    "aarch64-unknown-linux-musl" = "0r4j2vhvmsxhi95a544d59fbx55kna7wkwii99dq920m39gggcav";
  };

  # codex >= 0.143 spawns a separate `codex-code-mode-host` binary (found
  # next to the running executable) when "code mode" is enabled. Shipped as its
  # own release asset, so the native build must fetch and install it too.
  codeModeHostHashes = {
    "aarch64-apple-darwin" = "1gy14xmmaxkqpr1jn29jkl9wy2llwzny42wkn45ha2n3v80jhd0f";
    "x86_64-apple-darwin" = "1p4gd8zlrn3c9pjnmy8wq2g2r33wfm9vw3rzmgcycn0g896vn8m9";
    "x86_64-unknown-linux-musl" = "1iagxs6v1gmzkfclsky54qwyzcmg332gvik0qkdzdk95c626fxml";
    "aarch64-unknown-linux-musl" = "173gza8vyzfp7rzjx46zhc07y2gjwz5jbq4n62npgskdlf54m4yc";
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
