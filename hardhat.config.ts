import '@nomiclabs/hardhat-ethers';
import { HardhatUserConfig, task } from 'hardhat/config';
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
	networks
};

export default config;
