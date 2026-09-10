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
  version = "0.154.0";

  platformMap = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or
    (throw "Codex is not supported on ${stdenv.hostPlatform.system}. Supported: aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux");

  nativeHashes = {
    "aarch64-apple-darwin" = "1mzrrvmiczna671smflqjiy90s8s682g7vsgw29b3hcilnh10hrl";
    "x86_64-apple-darwin" = "1rx630z7l0yfwqznvg3rcahrqpcb0g02bh94lj9v84zqv0vwh68j";
    "x86_64-unknown-linux-musl" = "00kzq045shxniy3djd6nxp4xnj7gvs89xviibwpj93xfjwjqpqfp";
    "aarch64-unknown-linux-musl" = "09rwld7m42nc4skmg9qzh9047cq6vdd2x31krnyi6hl06bglhfsq";
  };

  # codex >= 0.143 spawns a separate `codex-code-mode-host` binary (found
  # next to the running executable) when "code mode" is enabled. Shipped as its
  # own release asset, so the native build must fetch and install it too.
  codeModeHostHashes = {
    "aarch64-apple-darwin" = "1bbgr1fn8hs1xwac4c3gk00xpl81wbcdgrsjj18sx6555shf43jh";
    "x86_64-apple-darwin" = "1zl76fwxpr1i673sd8wzzdxk24kjg7z9qn3av314vx4iwm0n3ym0";
    "x86_64-unknown-linux-musl" = "1xq1mx0xd1jb4nhk64yx98ikmiv1vvvpsrvmw76sfv9wlb6gg3d6";
    "aarch64-unknown-linux-musl" = "1ynbdnv347kipngxnswwfkywfxjz9aavy499wfbb88i05hqgmbi0";
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
