{
  lib,
  python3Packages,
  fetchgit,
  zip,
}:
python3Packages.buildPythonApplication rec {
  pname = "blender-mcp";
  version = "1.0.3";
  pyproject = true;

  src = fetchgit {
    url = "https://projects.blender.org/lab/blender_mcp.git";
    rev = "2cea8d566dde07fbac28a61d698909d69724e853";
    hash = "sha256-pYeByO4Oi5eyynsJhGVd1vBWXHvhGn+Y5LGit6Kazlw=";
  };
  sourceRoot = "${src.name}/mcp";

  build-system = [ python3Packages.setuptools ];
  nativeBuildInputs = [ zip ];
  dependencies =
    with python3Packages;
    [
      docutils
      mcp
      pyyaml
    ]
    ++ python3Packages.mcp.optional-dependencies.cli;

  postInstall = ''
    mkdir -p "$out/share/blender-mcp"
    (cd ../addon/blender_mcp_addon && zip -r "$out/share/blender-mcp/mcp.zip" .)
  '';

  checkPhase = ''
    runHook preCheck
    substituteInPlace ../tests/test_tool_listing.py \
      --replace-fail 'command=sys.executable,' 'command="'$out'/bin/blender-mcp",' \
      --replace-fail 'args=["-m", "blmcp"],' 'args=[],'
    python ../tests/test_tool_listing.py
    runHook postCheck
  '';
  pythonImportsCheck = [ "blmcp" ];

  meta = {
    description = "Official Blender Lab MCP server";
    homepage = "https://projects.blender.org/lab/blender_mcp";
    license = lib.licenses.gpl3Plus;
    mainProgram = "blender-mcp";
  };
}
