await Bun.build({
  entrypoints: ["server.ts"],
  compile: { outfile: "dist/kelivo-agent-sidecar.exe" },
});
await Bun.write("dist/package.json", await Bun.file("package.json").text());
