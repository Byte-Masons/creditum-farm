async function main() {
  const vaultAddress = '0x63AFF1c026b79f28990A8E81eEB8b5D4c306DB1B';
  const strategyAddress = '0xd7c7Be67819247eBB8fc8Ec8922b2d101d8514D6';

  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress);

  await vault.initialize(strategyAddress);
  console.log('Vault initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
