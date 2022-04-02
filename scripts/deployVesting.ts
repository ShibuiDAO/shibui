import assert from 'assert';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import ora from 'ora';
import {
	A1_ADDRESS,
	A2_ADDRESS,
	A_DISTRIBUTION,
	C1_ADDRESS,
	C_DISTRIBUTION,
	F1_ADDRESS,
	F_DISTRIBUTION,
	BOBA_MAINNET_SHIBUI_ADDRESS,
	OOLONG_PAIR_CREATION_DISTRIBUTION,
	TOTAL_SUPPLY,
	WEEK_IN_SECONDS
} from '../constants';
import type { Shibui, VestingShibui__factory } from '../typechain';

const NOW = new Date();
const VEST_END_TIMESTAMP = BigNumber.from(NOW.getTime()).add(BigNumber.from(WEEK_IN_SECONDS).mul(4).mul(6));

async function main() {
	assert.notEqual(BOBA_MAINNET_SHIBUI_ADDRESS, '');
	assert.notEqual(F1_ADDRESS, '');
	assert.notEqual(C1_ADDRESS, '');
	assert.notEqual(A1_ADDRESS, '');
	assert.notEqual(A2_ADDRESS, '');

	assert.equal(
		BigNumber.from(0).add(F_DISTRIBUTION).add(C_DISTRIBUTION).add(BigNumber.from(A_DISTRIBUTION).mul(2)).toBigInt() <=
			BigNumber.from(TOTAL_SUPPLY).sub(OOLONG_PAIR_CREATION_DISTRIBUTION).toBigInt(),
		true
	);

	const spinner = ora('Deploying vesting sets').start();
	const [deployer] = await ethers.getSigners();

	const Shibui = (await ethers.getContractAt('Shibui', BOBA_MAINNET_SHIBUI_ADDRESS)) as Shibui;

	const VestingShibuiContract = (await ethers.getContractFactory('VestingShibui')) as VestingShibui__factory;

	spinner.text = 'Deploying "VestingShibui" contract for "F1"';
	const F1_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, F1_ADDRESS);
	await F1_VestingShibui.deployed();
	spinner.text = 'Transferring Shibui tokens to "VestingShibui" for "F1"';
	await Shibui.mintAmount(F1_VestingShibui.address, F_DISTRIBUTION);
	spinner.text = 'Starting vesting for "F1"';
	await F1_VestingShibui.vest(VEST_END_TIMESTAMP);

	spinner.text = 'Deploying "VestingShibui" contract for "C1"';
	const C1_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, C1_ADDRESS);
	await C1_VestingShibui.deployed();
	spinner.text = 'Transferring Shibui tokens to "VestingShibui" for "C1"';
	await Shibui.mintAmount(C1_VestingShibui.address, C_DISTRIBUTION);
	spinner.text = 'Starting vesting for "C1"';
	await C1_VestingShibui.vest(VEST_END_TIMESTAMP);

	spinner.text = 'Deploying "VestingShibui" contract for "A1"';
	const A1_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, A1_ADDRESS);
	await A1_VestingShibui.deployed();
	spinner.text = 'Transferring Shibui tokens to "VestingShibui" for "A1"';
	await Shibui.mintAmount(A1_VestingShibui.address, A_DISTRIBUTION);
	spinner.text = 'Starting vesting for "A1"';
	await A1_VestingShibui.vest(VEST_END_TIMESTAMP);

	spinner.text = 'Deploying "VestingShibui" contract for "A2"';
	const A2_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, A2_ADDRESS);
	await A2_VestingShibui.deployed();
	spinner.text = 'Transferring Shibui tokens to "VestingShibui" for "A2"';
	await Shibui.mintAmount(A2_VestingShibui.address, A_DISTRIBUTION);
	spinner.text = 'Starting vesting for "A2"';
	await A2_VestingShibui.vest(VEST_END_TIMESTAMP);

	spinner.succeed();

	console.log(
		[
			'',
			` - "Shibui" deployed to ${Shibui.address}`,
			` - "VestingShibui" for "F1" deployed to ${F1_VestingShibui.address}`,
			` - "VestingShibui" for "C1" deployed to ${C1_VestingShibui.address}`,
			` - "VestingShibui" for "A1" deployed to ${A1_VestingShibui.address}`,
			` - "VestingShibui" for "A2" deployed to ${A2_VestingShibui.address}`,
			`Deployer address is ${deployer.address}`
		].join('\n')
	);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
