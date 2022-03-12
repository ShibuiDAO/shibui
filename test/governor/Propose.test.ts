import chai, { expect } from 'chai';
import { solidity } from 'ethereum-waffle';
import { BigNumber } from 'ethers';
import { solidityPack } from 'ethers/lib/utils';
import { ethers, upgrades } from 'hardhat';
import { DAY_IN_SECONDS, PROPOSAL_THRESHOLD, TOTAL_SUPPLY, VOTING_DELAY, VOTING_PERIOD } from '../../constants';
import type { GovernorCharlie, GovernorCharlie__factory, Shibui, Shibui__factory, Timelock, Timelock__factory } from '../../typechain';

chai.use(solidity);

describe('GovernorCharlie#propose', () => {
	let shibui: Shibui;
	let timelock: Timelock;
	let governor: GovernorCharlie;

	beforeEach(async () => {
		const [, minter, a0] = await ethers.getSigners();

		const ShibuiContract = (await ethers.getContractFactory('Shibui')) as Shibui__factory;
		shibui = await ShibuiContract.deploy();
		await shibui.deployed();

		await shibui.mintFull(minter.address);
		expect(await shibui.balanceOf(minter.address)).to.eql(TOTAL_SUPPLY);

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
