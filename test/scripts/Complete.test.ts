import chai, { expect } from 'chai';
import { solidity } from 'ethereum-waffle';
import { BigNumber } from 'ethers';
import { ethers, network, upgrades } from 'hardhat';
import {
	A_DISTRIBUTION,
	BOBA_DAO_DISTRIBUTION,
	C_DISTRIBUTION,
	DAY_IN_SECONDS,
	F_DISTRIBUTION,
	PROPOSAL_THRESHOLD,
	TREASURY_DISTRIBUTION,
	VOTING_DELAY,
	VOTING_PERIOD,
	WEEK_IN_SECONDS,
	ZERO_ADDRESS
} from '../../constants';
import type {
	GovernorCharlie,
	GovernorCharlie__factory,
	Shibui__factory,
	Timelock__factory,
	TokenManager__factory,
	VestingShibui__factory
} from '../../typechain';

chai.use(solidity);

describe('Deploy - "Complete"', () => {
	let NOW: Date;
	let VEST_END_TIMESTAMP: BigNumber;

	beforeEach(async () => {
		NOW = new Date((await ethers.provider.getBlock('latest')).timestamp);
		VEST_END_TIMESTAMP = BigNumber.from(NOW.getTime()).add(BigNumber.from(WEEK_IN_SECONDS).mul(4).mul(6));
	});

	it('should execute', async () => {
		const [deployer, F1, C1, A1, A2, BOBA_DAO] = await ethers.getSigners();

		const ShibuiContract = (await ethers.getContractFactory('Shibui')) as Shibui__factory;
		const Shibui = await ShibuiContract.deploy();
		await Shibui.deployed();

		await Shibui.mintFull(deployer.address);

		const TimelockContract = (await ethers.getContractFactory('Timelock')) as Timelock__factory;
		const Timelock = await TimelockContract.deploy(DAY_IN_SECONDS);
		await Timelock.deployed();

		const TokenManagerContract = (await ethers.getContractFactory('TokenManager')) as TokenManager__factory;
		const TokenManager = await TokenManagerContract.deploy();
		await TokenManager.deployed();

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

		const F1_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, F1.address);
		await F1_VestingShibui.deployed();
		await Shibui.transfer(F1_VestingShibui.address, F_DISTRIBUTION);
		await F1_VestingShibui.vest(VEST_END_TIMESTAMP);

		const C1_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, C1.address);
		await C1_VestingShibui.deployed();
		await Shibui.transfer(C1_VestingShibui.address, C_DISTRIBUTION);
		await C1_VestingShibui.vest(VEST_END_TIMESTAMP);

		const A1_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, A1.address);
		await A1_VestingShibui.deployed();
		await Shibui.transfer(A1_VestingShibui.address, A_DISTRIBUTION);
		await A1_VestingShibui.vest(VEST_END_TIMESTAMP);

		const A2_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, A2.address);
		await A2_VestingShibui.deployed();
		await Shibui.transfer(A2_VestingShibui.address, A_DISTRIBUTION);
		await A2_VestingShibui.vest(VEST_END_TIMESTAMP);

		await Shibui.lockHolder(BOBA_DAO.address);
		await Shibui.transfer(BOBA_DAO.address, BOBA_DAO_DISTRIBUTION);

		await Shibui.transfer(TokenManager.address, TREASURY_DISTRIBUTION);

		await Shibui.transferOwnership(Timelock.address);
		await TokenManager.transferOwnership(Timelock.address);

		await Timelock.proposeOwner(GovernorCharlie.address);

		await F1_VestingShibui.transferOwnership(Timelock.address);
		await C1_VestingShibui.transferOwnership(Timelock.address);
		await A1_VestingShibui.transferOwnership(Timelock.address);
		await A2_VestingShibui.transferOwnership(Timelock.address);

		await GovernorCharlie.govern(BigNumber.from(1));

		// TESTING DEPLOYED STATE

		// const blockNumberBeforeMine = await ethers.provider.getBlockNumber();
		await network.provider.send('evm_mine');
		// const blockNumberAfterMine = await ethers.provider.getBlockNumber();

		expect(await Shibui.getCurrentVotes(F1.address)).to.eql(F_DISTRIBUTION);
		expect(await Shibui.getCurrentVotes(C1.address)).to.eql(C_DISTRIBUTION);
		expect(await Shibui.getCurrentVotes(A1.address)).to.eql(A_DISTRIBUTION);
		expect(await Shibui.getCurrentVotes(A2.address)).to.eql(A_DISTRIBUTION);

		expect(await Shibui.balanceOf(await F1_VestingShibui.beneficiary())).to.eql(BigNumber.from(0));
		expect(await Shibui.balanceOf(await C1_VestingShibui.beneficiary())).to.eql(BigNumber.from(0));
		expect(await Shibui.balanceOf(await A1_VestingShibui.beneficiary())).to.eql(BigNumber.from(0));
		expect(await Shibui.balanceOf(await A2_VestingShibui.beneficiary())).to.eql(BigNumber.from(0));

		await expect(F1_VestingShibui.release()).to.revertedWith('TIME_BEFORE_RELEASE');
		await expect(C1_VestingShibui.release()).to.revertedWith('TIME_BEFORE_RELEASE');
		await expect(A1_VestingShibui.release()).to.revertedWith('TIME_BEFORE_RELEASE');
		await expect(A2_VestingShibui.release()).to.revertedWith('TIME_BEFORE_RELEASE');

		await network.provider.send('evm_increaseTime', [VEST_END_TIMESTAMP.toNumber()]);

		await F1_VestingShibui.release();
		await C1_VestingShibui.release();
		await A1_VestingShibui.release();
		await A2_VestingShibui.release();

		expect(await Shibui.balanceOf(F1_VestingShibui.address)).to.eql(BigNumber.from(0));
		expect(await Shibui.balanceOf(C1_VestingShibui.address)).to.eql(BigNumber.from(0));
		expect(await Shibui.balanceOf(A1_VestingShibui.address)).to.eql(BigNumber.from(0));
		expect(await Shibui.balanceOf(A2_VestingShibui.address)).to.eql(BigNumber.from(0));

		expect(await Shibui.getCurrentVotes(F1.address)).to.eql(BigNumber.from(0));
		expect(await Shibui.balanceOf(F1.address)).to.eql(F_DISTRIBUTION);
		expect(await Shibui.getCurrentVotes(C1.address)).to.eql(BigNumber.from(0));
		expect(await Shibui.balanceOf(C1.address)).to.eql(C_DISTRIBUTION);
		expect(await Shibui.getCurrentVotes(A1.address)).to.eql(BigNumber.from(0));
		expect(await Shibui.balanceOf(A1.address)).to.eql(A_DISTRIBUTION);
		expect(await Shibui.getCurrentVotes(A2.address)).to.eql(BigNumber.from(0));
		expect(await Shibui.balanceOf(A2.address)).to.eql(A_DISTRIBUTION);

		await expect(F1_VestingShibui.release()).to.revertedWith('BALANCE_EMPTY');
		await expect(C1_VestingShibui.release()).to.revertedWith('BALANCE_EMPTY');
		await expect(A1_VestingShibui.release()).to.revertedWith('BALANCE_EMPTY');
		await expect(A2_VestingShibui.release()).to.revertedWith('BALANCE_EMPTY');

		expect(await Shibui.balanceOf(TokenManager.address)).to.eql(TREASURY_DISTRIBUTION);
		expect(await Shibui.getCurrentVotes(TokenManager.address)).to.eql(BigNumber.from(0));

		// Votes are not present if not delegated. For a user to have votes they have to delegate them to themselves.
		expect(await Shibui.getCurrentVotes(BOBA_DAO.address)).to.eql(BigNumber.from(0));

		await expect(Shibui.connect(BOBA_DAO).delegate(BOBA_DAO.address))
			.to.emit(Shibui, 'DelegateChanged')
			.withArgs(BOBA_DAO.address, ZERO_ADDRESS, BOBA_DAO.address);
		expect(await Shibui.getCurrentVotes(BOBA_DAO.address)).to.eql(BOBA_DAO_DISTRIBUTION);

		await expect(Shibui.connect(BOBA_DAO).transfer(deployer.address, 1)).to.revertedWith('HOLDER_LOCKED_FROM_TRANSFER');
	});
});
