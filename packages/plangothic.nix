/*
  Adapted from linyinfeng/nur-packages, pkgs/plangothic/default.nix.

  MIT License

  Copyright (c) 2020-2021 Lin Yinfeng

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
*/
{
  stdenv,
  fetchurl,
  p7zip,
  lndir,
  lib,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "plangothic";
  version = "2.9.5795";
  src = fetchurl {
    url = "https://github.com/Fitzgerald-Porthmouth-Koenigsegg/Plangothic_Project/releases/download/V${finalAttrs.version}/Plangothic-Super-V${finalAttrs.version}.7z";
    sha256 = "sha256-L6Zs/fiMByDzkLRsCxLbC/HL4Dsg9LyglDV3hEfqYKo=";
  };
  nativeBuildInputs = [
    p7zip
    lndir
  ];
  outputs = [
    "out"
    "otc"
    "otf"
    "ttc"
    "ttf"
    "woff2"
  ];
  installPhase = ''
    runHook preInstall
    install -D --mode=444 otf/*.ttc    --target-directory="$otc/share/fonts/opentype/"
    install -D --mode=444 otf/*.otf    --target-directory="$otf/share/fonts/opentype/"
    install -D --mode=444 static/*.ttc --target-directory="$ttc/share/fonts/truetype/"
    install -D --mode=444 static/*.ttf --target-directory="$ttf/share/fonts/truetype/"
    install -D --mode=444 web/*.woff2  --target-directory="$woff2/share/fonts/woff2/"
    mkdir --parents "$out/share/fonts"
    for format_dir in "$otc" "$otf" "$ttc" "$ttf" "$woff2"; do
      lndir "$format_dir" "$out"
    done
    runHook postInstall
  '';

  meta = {
    homepage = "https://github.com/Fitzgerald-Porthmouth-Koenigsegg/Plangothic_Project";
    description = "Font based on Source Han Sans, following Mainland China glyph standards, with glyph coverage for the CJK Unified Ideographs Extension blocks.";
    license = lib.licenses.ofl;
  };
})
