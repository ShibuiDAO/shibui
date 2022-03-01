import { BigNumber } from 'ethers';
import { ethers, upgrades } from 'hardhat';
import type {
	GovernorCharlie,
	GovernorCharlie__factory,
	Shibui__factory,
	Timelock__factory,
	TokenManager__factory,
	VestingShibui__factory
} from '../typechain';

const DAY_IN_SECONDS = BigNumber.from(1).mul(1).mul(24).mul(60).mul(60);

const F1_ADDRESS = '';
const C1_ADDRESS = '0x147439cBFb58fbb13a3149BCd9159d21fbD9F799';
const A1_ADDRESS = '';
const A2_ADDRESS = '';

const DECIMALS = BigNumber.from(10).pow(18);

const F_DISTRIBUTION = BigNumber.from(DECIMALS).mul(10_000_000);
const C_DISTRIBUTION = BigNumber.from(DECIMALS).mul(500_000);
const A_DISTRIBUTION = BigNumber.from(DECIMALS).mul(2_000_000);

const NOW = new Date();
const VEST_END = new Date(NOW);
VEST_END.setMonth(NOW.getMonth() + 6);

const VEST_END_TIMESTAMP = BigNumber.from(VEST_END.getTime());

async function main() {
	const [deployer] = await ethers.getSigners();

	const ShibuiContract = (await ethers.getContractFactory('Shibui')) as Shibui__factory;
	const Shibui = await ShibuiContract.deploy(deployer.address);
	await Shibui.deployed();

	const TimelockContract = (await ethers.getContractFactory('Timelock')) as Timelock__factory;
	const Timelock = await TimelockContract.deploy(DAY_IN_SECONDS);
	await Timelock.deployed();

	const TokenManagerContract = (await ethers.getContractFactory('TokenManager')) as TokenManager__factory;
	const TokenManager = await TokenManagerContract.deploy();
	await TokenManager.deployed();

	const GovernorCharlieContract = (await ethers.getContractFactory('GovernorCharlie')) as GovernorCharlie__factory;
	const GovernorCharlie = (await upgrades.deployProxy(GovernorCharlieContract, [Timelock.address, Shibui.address], {
		initializer: '__GovernorCharlie_init',
		kind: 'transparent'
	})) as GovernorCharlie;
	await GovernorCharlie.deployed();

	const VestingShibuiContract = (await ethers.getContractFactory('VestingShibui')) as VestingShibui__factory;

	const F1_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, F1_ADDRESS);
	await F1_VestingShibui.deployed();
	await Shibui.transfer(F1_VestingShibui.address, F_DISTRIBUTION);
	await F1_VestingShibui.vest(VEST_END_TIMESTAMP);

	const C1_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, C1_ADDRESS);
	await C1_VestingShibui.deployed();
	await Shibui.transfer(C1_VestingShibui.address, C_DISTRIBUTION);
	await C1_VestingShibui.vest(VEST_END_TIMESTAMP);

	const A1_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, A1_ADDRESS);
	await A1_VestingShibui.deployed();
	await Shibui.transfer(A1_VestingShibui.address, A_DISTRIBUTION);
	await A1_VestingShibui.vest(VEST_END_TIMESTAMP);

	const A2_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, A2_ADDRESS);
	await A2_VestingShibui.deployed();
	await Shibui.transfer(A2_VestingShibui.address, A_DISTRIBUTION);
	await A2_VestingShibui.vest(VEST_END_TIMESTAMP);

	await Shibui.transferOwnership(Timelock.address);
	await TokenManager.transferOwnership(Timelock.address);
	await Timelock.proposeOwner(GovernorCharlie.address);

	await F1_VestingShibui.transferOwnership(Timelock.address);
	await C1_VestingShibui.transferOwnership(Timelock.address);
	await C1_VestingShibui.transferOwnership(Timelock.address);
	await A2_VestingShibui.transferOwnership(Timelock.address);

	await GovernorCharlie.govern(BigNumber.from(1));

	// console.log(
	// 	[
	// 		` - "OrderBookUpgradeable" deployed to ${OrderBookUpgradeable.address}`,
	// 		` - "ERC721ExchangeUpgradeable" deployed to ${ERC721ExchangeUpgradeable.address}`,
	// 		`Deployer address is ${deployer.address}`
	// 	].join('\n')
	// );
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
