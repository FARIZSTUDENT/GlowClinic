// Deploy ke jaringan EVM mana pun (default: Polygon Amoy testnet).
// Wajib: DEPLOYER_PRIVATE_KEY. Opsional: RPC_URL.
const fs = require('fs');
const path = require('path');
const { ethers } = require('ethers');

(async () => {
  const rpc = process.env.RPC_URL || 'https://rpc-amoy.polygon.technology';
  const pk = process.env.DEPLOYER_PRIVATE_KEY;
  if (!pk) throw new Error('Set DEPLOYER_PRIVATE_KEY (kunci wallet testnet, JANGAN wallet utama)');

  const art = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'build', 'GlowRegistry.json'), 'utf8'));
  const provider = new ethers.JsonRpcProvider(rpc);
  const wallet = new ethers.Wallet(pk, provider);
  const net = await provider.getNetwork();
  console.log('Jaringan :', net.name, 'chainId', net.chainId.toString());
  console.log('Deployer :', wallet.address);
  console.log('Saldo    :', ethers.formatEther(await provider.getBalance(wallet.address)));

  const factory = new ethers.ContractFactory(art.abi, art.bytecode, wallet);
  const c = await factory.deploy();
  await c.waitForDeployment();
  console.log('\nGlowRegistry di-deploy ke:', await c.getAddress());
  console.log('Tx deploy:', c.deploymentTransaction().hash);
})().catch((e) => { console.error(e.message); process.exit(1); });
