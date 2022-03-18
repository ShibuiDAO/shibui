import chai, { expect } from 'chai';
import { solidity } from 'ethereum-waffle';
import { BigNumber } from 'ethers';
import { ethers, network } from 'hardhat';
import { A_DISTRIBUTION, C_DISTRIBUTION, F_DISTRIBUTION, OOLONG_PAIR_CREATION_DISTRIBUTION, WEEK_IN_SECONDS } from '../../constants';
import type { Shibui, Shibui__factory, VestingShibui__factory } from '../../typechain';

chai.use(solidity);

describe('Deploy - "Vesting"', () => {
	let NOW: Date;
	let VEST_END_TIMESTAMP: BigNumber;

	beforeEach(async () => {
		NOW = new Date((await ethers.provider.getBlock('latest')).timestamp);
		VEST_END_TIMESTAMP = BigNumber.from(NOW.getTime()).add(BigNumber.from(WEEK_IN_SECONDS).mul(4).mul(6));
	});

	it('should execute', async () => {
		const [deployer, F1, C1, A1, A2] = await ethers.getSigners();

		// PREP PRE SCRIPT STATE

		const ShibuiContract = (await ethers.getContractFactory('Shibui')) as Shibui__factory;
		const _Shibui = await ShibuiContract.deploy();
		await _Shibui.deployed();

		// SCRIPT LOGIC

		const Shibui = (await ethers.getContractAt('Shibui', _Shibui.address)) as Shibui;

		await Shibui.connect(deployer).mintAmount(deployer.address, OOLONG_PAIR_CREATION_DISTRIBUTION);

		const VestingShibuiContract = (await ethers.getContractFactory('VestingShibui')) as VestingShibui__factory;

		const F1_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, F1.address);
		await F1_VestingShibui.deployed();
		await Shibui.mintAmount(F1_VestingShibui.address, F_DISTRIBUTION);
		await F1_VestingShibui.vest(VEST_END_TIMESTAMP);

		const C1_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, C1.address);
		await C1_VestingShibui.deployed();
		await Shibui.mintAmount(C1_VestingShibui.address, C_DISTRIBUTION);
		await C1_VestingShibui.vest(VEST_END_TIMESTAMP);

		const A1_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, A1.address);
		await A1_VestingShibui.deployed();
		await Shibui.mintAmount(A1_VestingShibui.address, A_DISTRIBUTION);
		await A1_VestingShibui.vest(VEST_END_TIMESTAMP);

		const A2_VestingShibui = await VestingShibuiContract.deploy(Shibui.address, A2.address);
		await A2_VestingShibui.deployed();
		await Shibui.mintAmount(A2_VestingShibui.address, A_DISTRIBUTION);
		await A2_VestingShibui.vest(VEST_END_TIMESTAMP);

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
	});
});
