import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import ora from 'ora';
import { BOBA_BREWERY_IDO_ADDRESS, BOBA_BREWERY_IDO_DISTRIBUTION, BOBA_MAINNET_SHIBUI_ADDRESS, DECIMALS } from '../constants';
import type { Shibui } from '../typechain';

async function main() {
	const spinner = ora('Minting Boba Brewery IDO distribution').start();
	const [deployer] = await ethers.getSigners();

	const Shibui = (await ethers.getContractAt('Shibui', BOBA_MAINNET_SHIBUI_ADDRESS)) as Shibui;

	await Shibui.connect(deployer).mintAmount(BOBA_BREWERY_IDO_ADDRESS, BOBA_BREWERY_IDO_DISTRIBUTION);

	spinner.succeed();

	console.log(`Minted ${BigNumber.from(BOBA_BREWERY_IDO_DISTRIBUTION).div(DECIMALS).toString()}🌊 to "${BOBA_BREWERY_IDO_ADDRESS}"`);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
