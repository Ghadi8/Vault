module.exports = {
  devnet: {
    escapeHatchCaller: "0x93c7ad4f81b2894f5c16657eefd5029a7f6a3b96", //second account
    escapeHatchDestination: "0x4379042c27929d2a206291293977aaa5a8ca3043", //third account
    absoluteMinTimeLock: 600,
    timeLock: 1000,
    securityGuard: "0xcaabe6202230a3a71b57b445d69233dacb5da243", // fourth account
    maxSecurityGuardDelay: 100,
  },
  goerli: {},
  mainnet: {},
};
