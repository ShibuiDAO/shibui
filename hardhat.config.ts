import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import '@openzeppelin/hardhat-upgrades';
import '@typechain/hardhat';
import 'hardhat-abi-exporter';
import 'hardhat-gas-reporter';
import { HardhatUserConfig, task } from 'hardhat/config';
import 'solidity-coverage';
import { coinMarketCapApi } from './config.hardhat';
import { networks } from './networks.hardhat';

task('accounts', 'Prints the list of accounts', async (_, hre) => {
	const accounts = await hre.ethers.getSigners();

	for (const account of accounts) {
		console.log(account.address);
	}
});

const config: HardhatUserConfig = {
	paths: {
		sources: './src/contracts',
		tests: './test'
	},
	solidity: {
		version: '0.8.9',
		settings: {
			optimizer: {
				enabled: true,
				runs: 2000
			}
		}
	},
	defaultNetwork: 'hardhat',
	networks,
	abiExporter: {
		path: './abis',
		runOnCompile: true,
		clear: true,
		flat: true,
		only: ['Shibui.sol', 'TokenManager.sol', 'Timelock.sol', 'L1Executor.sol', 'GovernorCharlie.sol', 'VestingShibui.sol']
	},
	typechain: {
		outDir: 'typechain',
		target: 'ethers-v5',
		alwaysGenerateOverloads: false
	},
	gasReporter: {
		excludeContracts: ['contracts/mocks/', 'src/contracts/mocks/', 'test/', 'src/test/'],
		showTimeSpent: true,
		currency: 'USD',
		gasPrice: 1,
		coinmarketcap: coinMarketCapApi
	}
};

export default config;
