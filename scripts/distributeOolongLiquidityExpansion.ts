import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import ora from 'ora';
import { DECIMALS, BOBA_MAINNET_SHIBUI_ADDRESS, OOLONG_LIQUIDITY_EXPANSION_DISTRIBUTION } from '../constants';
import type { Shibui } from '../typechain';

async function main() {
	const spinner = ora('Minting OolongSwap liquidity expansion distribution').start();
	const [deployer] = await ethers.getSigners();

	const Shibui = (await ethers.getContractAt('Shibui', BOBA_MAINNET_SHIBUI_ADDRESS)) as Shibui;

	await Shibui.connect(deployer).mintAmount(deployer.address, OOLONG_LIQUIDITY_EXPANSION_DISTRIBUTION);

	spinner.succeed();

	console.log(`Minted ${BigNumber.from(OOLONG_LIQUIDITY_EXPANSION_DISTRIBUTION).div(DECIMALS).toString()}🌊 to "${deployer.address}"`);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
