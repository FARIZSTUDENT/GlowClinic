// Test end-to-end terhadap node lokal Hardhat (jalankan: npx hardhat node, lalu npm test)
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const { ethers } = require('ethers');

(async () => {
  const rpc = process.env.RPC_URL || 'http://127.0.0.1:8545';
  const provider = new ethers.JsonRpcProvider(rpc);
  const [ownerAddr, otherAddr] = await provider.listAccounts();
  const owner = await provider.getSigner(ownerAddr.address);
  const other = await provider.getSigner(otherAddr.address);
  const art = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'build', 'GlowRegistry.json'), 'utf8'));

  const c = await (await new ethers.ContractFactory(art.abi, art.bytecode, owner).deploy()).waitForDeployment();
  const h = ethers.sha256(ethers.toUtf8Bytes('booking:1:2:IDR:150000'));

  assert.equal(await c.verify(h), 0n);
  const rc = await (await c.anchor(h, 'booking')).wait();
  assert.ok((await c.verify(h)) > 0n, 'hash harus tercatat');
  assert.equal(await c.totalAnchored(), 1n);
  assert.equal(rc.logs.length, 1, 'event Anchored harus ter-emit');

  await assert.rejects(c.anchor(h, 'booking'), /AlreadyAnchored|revert/, 'duplikat harus ditolak');
  await assert.rejects(c.connect(other).anchor(ethers.sha256('0x01'), 'x'), /NotOwner|revert/, 'non-owner harus ditolak');
  const tampered = ethers.sha256(ethers.toUtf8Bytes('booking:1:2:IDR:1'));
  assert.equal(await c.verify(tampered), 0n, 'data yang diubah tidak boleh cocok');
  console.log('Semua test lulus ✅');
})().catch((e) => { console.error('GAGAL:', e.message); process.exit(1); });
