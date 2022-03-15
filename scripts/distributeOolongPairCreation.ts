import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import ora from 'ora';
import { DECIMALS, OOLONG_PAIR_CREATION_DISTRIBUTION } from '../constants';
import type { Shibui } from '../typechain';

const SHIBUI_ADDRESS = '0xF08AD7C3f6b1c6843ba027AD54Ed8DDB6D71169b';

async function main() {
	const spinner = ora('Minting OolongSwap pair creation distribution').start();
	const [deployer] = await ethers.getSigners();

	const Shibui = (await ethers.getContractAt('Shibui', SHIBUI_ADDRESS)) as Shibui;

	await Shibui.connect(deployer).mintAmount(deployer.address, OOLONG_PAIR_CREATION_DISTRIBUTION);

	spinner.succeed();

	console.log(`Minted ${BigNumber.from(OOLONG_PAIR_CREATION_DISTRIBUTION).div(DECIMALS).toString()}🌊 to "${deployer.address}"`);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
