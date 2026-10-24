// Compile contracts/GlowRegistry.sol -> build/GlowRegistry.json (abi + bytecode)
const fs = require('fs');
const path = require('path');
const solc = require('solc');

const file = path.join(__dirname, '..', 'contracts', 'GlowRegistry.sol');
const input = {
  language: 'Solidity',
  sources: { 'GlowRegistry.sol': { content: fs.readFileSync(file, 'utf8') } },
  settings: {
    optimizer: { enabled: true, runs: 200 },
    outputSelection: { '*': { '*': ['abi', 'evm.bytecode.object'] } },
  },
};
const out = JSON.parse(solc.compile(JSON.stringify(input)));
const errors = (out.errors || []).filter((e) => e.severity === 'error');
(out.errors || []).forEach((e) => console.log(e.formattedMessage));
if (errors.length) process.exit(1);

const c = out.contracts['GlowRegistry.sol'].GlowRegistry;
const dir = path.join(__dirname, '..', 'build');
fs.mkdirSync(dir, { recursive: true });
fs.writeFileSync(
  path.join(dir, 'GlowRegistry.json'),
  JSON.stringify({ abi: c.abi, bytecode: '0x' + c.evm.bytecode.object }, null, 2),
);
console.log('OK -> build/GlowRegistry.json');
