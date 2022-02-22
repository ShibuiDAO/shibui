import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-abi-exporter';
import 'hardhat-gas-reporter';
import { HardhatUserConfig, task } from 'hardhat/config';
import 'solidity-coverage';
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
		only: ['Shibui.sol']
	},
	typechain: {
		outDir: 'typechain',
		target: 'ethers-v5',
		alwaysGenerateOverloads: false
	}
};

export default config;
