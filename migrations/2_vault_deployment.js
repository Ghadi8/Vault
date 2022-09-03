const vaultCont = artifacts.require("Vault");

const { setEnvValue } = require("../utils/env-man");

const conf = require("../migration-parameters");

const setVault = (n, v) => {
  setEnvValue("../", `Vault_ADDRESS${n.toUpperCase()}`, v);
};

module.exports = async (deployer, network, accounts) => {
  switch (network) {
    case "goerli":
      c = { ...conf.goerli };
      break;
    case "mainnet":
      c = { ...conf.mainnet };
      break;
    case "development":
    default:
      c = { ...conf.devnet };
  }

  // deploy Vault
  await deployer.deploy(
    vaultCont,
    c.escapeHatchCaller,
    c.escapeHatchDestination,
    c.absoluteMinTimeLock,
    c.timeLock,
    c.securityGuard,
    c.maxSecurityGuardDelay
  );

  const vault = await vaultCont.deployed();

  if (vault) {
    console.log(
      `Deployed: Vault
       network: ${network}
       address: ${vault.address}
       creator: ${accounts[0]}
    `
    );
    setVault(network, vault.address);
  } else {
    console.log("Vault Deployment UNSUCCESSFUL");
  }
};
