import { BigNumber } from 'ethers';

export const DAY_IN_SECONDS = BigNumber.from(1).mul(1).mul(24).mul(60).mul(60);
export const WEEK_IN_SECONDS = BigNumber.from(DAY_IN_SECONDS).mul(7);

export const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

export const F1_ADDRESS = '0xf82d0ea7A2eDde6d30cAf8A1E6Fed09f726fD584';
export const C1_ADDRESS = '0x147439cBFb58fbb13a3149BCd9159d21fbD9F799';
export const A1_ADDRESS = '0x25a98B269F4200A53fA8352d64f5115bb1Ef05eb';
export const A2_ADDRESS = '0xDF10742993eC99c895B2166267eAA4ce864209A8';
export const BOBA_DAO_ADDRESS = '0x2CC555B5B1a4Cf7fA5401B29ab46fc5ba2e205b0';
export const BOBA_BREWERY_IDO_ADDRESS = '0x1c6c6eB5942f99400Da8e8b3A7540038f02C81Ec';

export const DECIMALS = BigNumber.from(10).pow(18);

export const TOTAL_SUPPLY = BigNumber.from(DECIMALS).mul(50_000_000);

export const F_DISTRIBUTION = BigNumber.from(DECIMALS).mul(10_000_000);
export const C_DISTRIBUTION = BigNumber.from(DECIMALS).mul(500_000);
export const A_DISTRIBUTION = BigNumber.from(DECIMALS).mul(2_000_000);
export const BOBA_DAO_DISTRIBUTION = BigNumber.from(DECIMALS).mul(2_500_000);
export const TREASURY_DISTRIBUTION = BigNumber.from(DECIMALS).mul(20_000_000);

export const OOLONG_PAIR_CREATION_DISTRIBUTION = BigNumber.from(DECIMALS).mul(400);
export const OOLONG_LIQUIDITY_EXPANSION_DISTRIBUTION = BigNumber.from(DECIMALS).mul(800);

export const BOBA_BREWERY_IDO_DISTRIBUTION = BigNumber.from(DECIMALS).mul(2_300_000);

export const VOTING_PERIOD = BigNumber.from(DAY_IN_SECONDS);
export const VOTING_DELAY = BigNumber.from(1);
export const PROPOSAL_THRESHOLD = BigNumber.from(DECIMALS).mul(1_000_000);

export const BOBA_MAINNET_SHIBUI_ADDRESS = '0xF08AD7C3f6b1c6843ba027AD54Ed8DDB6D71169b';
