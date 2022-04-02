import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import ora from 'ora';
import { BOBA_DAO_ADDRESS, BOBA_DAO_DISTRIBUTION, BOBA_MAINNET_SHIBUI_ADDRESS, DECIMALS } from '../constants';
import type { Shibui } from '../typechain';

async function main() {
	const spinner = ora('Minting BobaDAO governance distribution').start();
	const [deployer] = await ethers.getSigners();

	const Shibui = (await ethers.getContractAt('Shibui', BOBA_MAINNET_SHIBUI_ADDRESS)) as Shibui;

	await Shibui.connect(deployer).lockHolder(BOBA_DAO_ADDRESS);
	await Shibui.connect(deployer).mintAmount(BOBA_DAO_ADDRESS, BOBA_DAO_DISTRIBUTION);

	spinner.succeed();

	console.log(`Minted ${BigNumber.from(BOBA_DAO_DISTRIBUTION).div(DECIMALS).toString()}🌊 to "${BOBA_DAO_ADDRESS}"`);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
