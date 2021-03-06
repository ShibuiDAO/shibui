import assert from 'assert';
import { BigNumber } from 'ethers';
import { ethers, upgrades } from 'hardhat';
import ora from 'ora';
import {
	A1_ADDRESS,
	A2_ADDRESS,
	A_DISTRIBUTION,
	BOBA_DAO_ADDRESS,
	BOBA_DAO_DISTRIBUTION,
	C1_ADDRESS,
	C_DISTRIBUTION,
	DAY_IN_SECONDS,
	F1_ADDRESS,
	F_DISTRIBUTION,
	PROPOSAL_THRESHOLD,
	TOTAL_SUPPLY,
	TREASURY_DISTRIBUTION,
	VOTING_DELAY,
	VOTING_PERIOD,
	WEEK_IN_SECONDS
} from '../constants';
import type {
	GovernorCharlie,
	GovernorCharlie__factory,
	Shibui__factory,
	Timelock__factory,
	TokenManager__factory,
	VestingShibui__factory
} from '../typechain';

const NOW = new Date();
const VEST_END_TIMESTAMP = BigNumber.from(NOW.getTime()).add(BigNumber.from(WEEK_IN_SECONDS).mul(4).mul(6));

// The deploy flow here is technically obsolete due to the deploy flow getting fragmented.
async function main() {
	assert.notEqual(F1_ADDRESS, '');
	assert.notEqual(C1_ADDRESS, '');
	assert.notEqual(A1_ADDRESS, '');
	assert.notEqual(A2_ADDRESS, '');

	assert.notEqual(BOBA_DAO_ADDRESS, '');

	assert.equal(
		BigNumber.from(0)
			.add(F_DISTRIBUTION)
			.add(C_DISTRIBUTION)
			.add(BigNumber.from(A_DISTRIBUTION).mul(2))
			.add(BOBA_DAO_DISTRIBUTION)
			.add(TREASURY_DISTRIBUTION)
			.toBigInt() <= TOTAL_SUPPLY.toBigInt(),
		true
	);

	const spinner = ora('Deploying contracts').start();
	const [deployer] = await ethers.getSigners();

	spinner.text = 'Deploying "Shibui" contract';
	const ShibuiContract = (await ethers.getContractFactory('Shibui')) as Shibui__factory;
	const Shibui = await ShibuiContract.deploy();
	await Shibui.deployed();

	await Shibui.mintFull(deployer.address);

	spinner.text = 'Deploying "Timelock" contract';
	const TimelockContract = (await ethers.getContractFactory('Timelock')) as Timelock__factory;
	const Timelock = await TimelockContract.deploy(DAY_IN_SECONDS);
	await Timelock.deployed();

	spinner.text = 'Deploying "TokenManager" contract';
	const TokenManagerContract = (await ethers.getContractFactory('TokenManager')) as TokenManager__factory;
	const TokenManager = await TokenManagerContract.deploy();
	await TokenManager.deployed();

	spinner.text = 'Deploying "GovernorCharlie" contract';
	const GovernorCharlieContract = (await ethers.getContractFactory('GovernorCharlie')) as GovernorCharlie__factory;
	const GovernorCharlie = (await upgrades.deployProxy(
		GovernorCharlieContract,
		[Timelock.address, Shibui.address, VOTING_PERIOD, VOTING_DELAY, PROPOSAL_THRESHOLD],
		{
			initializer: '__GovernorCharlie_init',
			kind: 'transparent'
		}
	)) as GovernorCharlie;
	await GovernorCharlie.deployed();

	const VestingShibuiContract = (await ethers.getContractFactory('VestingShibui')) as VestingShibui__factory;

	spinner.text = 'Deploying "VestingShibui" contract for "F1"';
	const F1_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, F1_ADDRESS);
	await F1_VestingShibui.deployed();
	spinner.text = 'Transferring Shibui tokens to "VestingShibui" for "F1"';
	await Shibui.transfer(F1_VestingShibui.address, F_DISTRIBUTION);
	spinner.text = 'Starting vesting for "F1"';
	await F1_VestingShibui.vest(VEST_END_TIMESTAMP);

	spinner.text = 'Deploying "VestingShibui" contract for "C1"';
	const C1_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, C1_ADDRESS);
	await C1_VestingShibui.deployed();
	spinner.text = 'Transferring Shibui tokens to "VestingShibui" for "C1"';
	await Shibui.transfer(C1_VestingShibui.address, C_DISTRIBUTION);
	spinner.text = 'Starting vesting for "C1"';
	await C1_VestingShibui.vest(VEST_END_TIMESTAMP);

	spinner.text = 'Deploying "VestingShibui" contract for "A1"';
	const A1_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, A1_ADDRESS);
	await A1_VestingShibui.deployed();
	spinner.text = 'Transferring Shibui tokens to "VestingShibui" for "A1"';
	await Shibui.transfer(A1_VestingShibui.address, A_DISTRIBUTION);
	spinner.text = 'Starting vesting for "A1"';
	await A1_VestingShibui.vest(VEST_END_TIMESTAMP);

	spinner.text = 'Deploying "VestingShibui" contract for "A2"';
	const A2_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, A2_ADDRESS);
	await A2_VestingShibui.deployed();
	spinner.text = 'Transferring Shibui tokens to "VestingShibui" for "A2"';
	await Shibui.transfer(A2_VestingShibui.address, A_DISTRIBUTION);
	spinner.text = 'Starting vesting for "A2"';
	await A2_VestingShibui.vest(VEST_END_TIMESTAMP);

	spinner.text = 'Locking "Boba DAO" from transferring Shibui tokens';
	await Shibui.lockHolder(BOBA_DAO_ADDRESS);
	spinner.text = 'Transferring Shibui tokens to "Boba DAO"';
	await Shibui.transfer(BOBA_DAO_ADDRESS, BOBA_DAO_DISTRIBUTION);

	spinner.text = 'Transferring Shibui tokens to "TokenManager" for "ShibuiDAO Treasury"';
	await Shibui.transfer(TokenManager.address, TREASURY_DISTRIBUTION);

	spinner.text = 'Transferring ownership of internal contract instances to ShibuiDAO Governance "Timelock"';
	await Shibui.transferOwnership(Timelock.address);
	await TokenManager.transferOwnership(Timelock.address);

	spinner.text = 'Proposing "GovernorCharlie" to be owner/admin of "Timelock"';
	await Timelock.proposeOwner(GovernorCharlie.address);

	spinner.text = 'Transferring ownership of "VestingShibui" instances to ShibuiDAO Governance "Timelock"';
	await F1_VestingShibui.transferOwnership(Timelock.address);
	await C1_VestingShibui.transferOwnership(Timelock.address);
	await A1_VestingShibui.transferOwnership(Timelock.address);
	await A2_VestingShibui.transferOwnership(Timelock.address);

	spinner.text = 'Enabling governance capabilities on "GovernorCharlie"';
	await GovernorCharlie.govern(BigNumber.from(1));

	spinner.succeed();

	console.log(
		[
			'',
			` - "Shibui" deployed to ${Shibui.address}`,
			` - "Timelock" deployed to ${Timelock.address}`,
			` - "TokenManager" deployed to ${TokenManager.address}`,
			` - "GovernorCharlie" deployed to ${GovernorCharlie.address}`,
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
