import chai, { expect } from 'chai';
import { solidity } from 'ethereum-waffle';
import { BigNumber } from 'ethers';
import { solidityPack } from 'ethers/lib/utils';
import { ethers, upgrades } from 'hardhat';
import type { GovernorCharlie, GovernorCharlie__factory, Shibui, Shibui__factory, Timelock, Timelock__factory } from '../../typechain';

chai.use(solidity);

const DECIMALS = BigNumber.from(10).pow(18);

describe('GovernorCharlie#propose', () => {
	let shibui: Shibui;
	let timelock: Timelock;
	let governor: GovernorCharlie;

	const DAY_IN_SECONDS = BigNumber.from(1).mul(1).mul(24).mul(60).mul(60);

	const VOTING_PERIOD = BigNumber.from(DAY_IN_SECONDS);
	const VOTING_DELAY = BigNumber.from(1);
	const PROPOSAL_THRESHOLD = BigNumber.from(DECIMALS).mul(1_000_000);

	beforeEach(async () => {
		const [, minter, a0] = await ethers.getSigners();

		const ShibuiContract = (await ethers.getContractFactory('Shibui')) as Shibui__factory;
		shibui = await ShibuiContract.deploy();
		await shibui.deployed();

		await shibui.fullMint(minter.address);

		const TimelockContract = (await ethers.getContractFactory('Timelock')) as Timelock__factory;
		timelock = await TimelockContract.deploy(DAY_IN_SECONDS);
		await timelock.deployed();

		const GovernorCharlieContract = (await ethers.getContractFactory('GovernorCharlie')) as GovernorCharlie__factory;
		governor = (await upgrades.deployProxy(
			GovernorCharlieContract,
			[timelock.address, shibui.address, VOTING_PERIOD, VOTING_DELAY, PROPOSAL_THRESHOLD],
			{
				initializer: '__GovernorCharlie_init',
				kind: 'transparent'
			}
		)) as GovernorCharlie;
		await governor.deployed();

		await timelock.proposeOwner(governor.address);
		await governor.govern(BigNumber.from(1));

		await shibui.connect(minter).delegate(a0.address);

		await expect(
			governor
				.connect(a0)
				.propose([shibui.address], [BigNumber.from(0)], ['getBalanceOf(address)'], [solidityPack(['address'], [minter.address])], 'nothing')
		).to.emit(governor, 'ProposalCreated');
	});

	describe('should initialize test data', () => {
		it('should create first proposal id', async () => {
			const [, , a0] = await ethers.getSigners();

			expect(await governor.latestProposalIds(a0.address)).to.eql(BigNumber.from(1));
		});
	});
});
