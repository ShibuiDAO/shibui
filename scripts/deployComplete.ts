import { BigNumber } from 'ethers';
import { ethers, upgrades } from 'hardhat';
import type { GovernorCharlie, GovernorCharlie__factory, Shibui__factory, Timelock__factory, TokenManager__factory } from '../typechain';

const DAY_IN_SECONDS = BigNumber.from(1).mul(1).mul(24).mul(60).mul(60);

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

	await Shibui.transferOwnership(Timelock.address);
	await TokenManager.transferOwnership(Timelock.address);
	await Timelock.proposeOwner(GovernorCharlie.address);
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
