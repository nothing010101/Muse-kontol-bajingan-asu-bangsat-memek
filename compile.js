// Compile all Puzzle NFT contracts with solc-js + OpenZeppelin imports.
// Usage: node compile.js
// Output: artifacts/<Contract>.json  { abi, bytecode }  (+ <Contract>.sol.json full output)
const fs = require("fs");
const path = require("path");
const solc = require("solc");

const ROOT = __dirname;
const CONTRACTS = ["TestToken", "AgentGate", "PuzzleRegistry", "ClueVault", "ClueFactory", "PuzzleNFT"];

function findImports(importPath) {
  try {
    let full;
    if (importPath.startsWith("@openzeppelin/")) {
      full = path.join(ROOT, "node_modules", importPath);
    } else {
      full = path.join(ROOT, importPath);
    }
    return { contents: fs.readFileSync(full, "utf8") };
  } catch (e) {
    return { error: "import not found: " + importPath };
  }
}

const input = {
  language: "Solidity",
  sources: Object.fromEntries(
    CONTRACTS.map((c) => [c + ".sol", { content: fs.readFileSync(path.join(ROOT, c + ".sol"), "utf8") }])
  ),
  settings: {
    evmVersion: "cancun",
    optimizer: { enabled: true, runs: 200 },
    outputSelection: { "*": { "*": ["abi", "evm.bytecode.object"] } },
  },
};

const output = JSON.parse(solc.compile(JSON.stringify(input), { import: findImports }));
const errors = (output.errors || []).filter((e) => e.severity === "error");
const warnings = (output.errors || []).filter((e) => e.severity === "warning");
for (const w of warnings) console.log("WARN:", w.formattedMessage);
if (errors.length) {
  for (const e of errors) console.log("ERROR:", e.formattedMessage);
  process.exit(1);
}

fs.mkdirSync(path.join(ROOT, "artifacts"), { recursive: true });
for (const c of CONTRACTS) {
  const compiled = output.contracts[c + ".sol"][c];
  if (!compiled) { console.log("MISSING:", c); process.exit(1); }
  fs.writeFileSync(
    path.join(ROOT, "artifacts", c + ".json"),
    JSON.stringify({ contractName: c, abi: compiled.abi, bytecode: "0x" + compiled.evm.bytecode.object }, null, 2)
  );
  console.log("OK", c, "bytecode bytes:", compiled.evm.bytecode.object.length / 2, "| abi entries:", compiled.abi.length);
}
console.log("solc version:", solc.version());
console.log("All contracts compiled with zero errors.");
