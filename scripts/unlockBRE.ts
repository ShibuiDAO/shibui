import { ethers } from 'hardhat';
import ora from 'ora';
import { BOBA_MAINNET_SHIBUI_ADDRESS } from '../constants';
import type { Shibui } from '../typechain';

async function main() {
	const spinner = ora('Unlocking any BRE related wallets').start();
	const [deployer] = await ethers.getSigners();

	const Shibui = (await ethers.getContractAt('Shibui', BOBA_MAINNET_SHIBUI_ADDRESS)) as Shibui;

	await Shibui.connect(deployer).unlockHolder('0x1c6c6eB5942f99400Da8e8b3A7540038f02C81Ec');
	await Shibui.connect(deployer).unlockHolder('0x3F714Fe1380eE2204ca499d1D8a171CBDfc39EaA');
	await Shibui.connect(deployer).unlockHolder('0xce9f38532b3d1e00a88e1f3347601dbc632e7a82');

	spinner.succeed();
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
