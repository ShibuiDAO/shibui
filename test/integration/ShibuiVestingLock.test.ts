import chai, { expect } from 'chai';
import { solidity } from 'ethereum-waffle';
import { BigNumber } from 'ethers';
import { ethers, network } from 'hardhat';
import type { Shibui, Shibui__factory, VestingShibui, VestingShibui__factory } from '../../typechain';

chai.use(solidity);

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

describe('VestingShibui - integration', () => {
	const TOTAL_SUPPLY = BigNumber.from(10).pow(18).mul(50_000_000);

	let shibui: Shibui;
	let vesting: VestingShibui;

	beforeEach(async () => {
		const [, minter, , a1] = await ethers.getSigners();

		const ShibuiContract = (await ethers.getContractFactory('Shibui')) as Shibui__factory;
		shibui = await ShibuiContract.deploy();
		await shibui.deployed();

		await shibui.mintFull(minter.address);

		const VestingShibuiContract = (await ethers.getContractFactory('VestingShibui')) as VestingShibui__factory;
		vesting = await VestingShibuiContract.deploy(shibui.address, a1.address);
		await vesting.deployed();

		await shibui.connect(minter).transfer(vesting.address, TOTAL_SUPPLY);
	});

	describe('ownable', () => {
		it('should swap ownership', async () => {
			const [deployer, , a0] = await ethers.getSigners();

			await expect(vesting.transferOwnership(a0.address)) //
				.to.emit(vesting, 'OwnershipTransferred')
				.withArgs(deployer.address, a0.address);
			const owner = await vesting.owner();

			expect(owner).to.equal(a0.address);
		});

		it('should fail to swap ownership', async () => {
			const [, , a0] = await ethers.getSigners();

			await expect(vesting.connect(a0).transferOwnership(a0.address)).to.be.revertedWith('Ownable: caller is not the owner');
		});

		it('should renounce ownership', async () => {
			const [deployer, , a0] = await ethers.getSigners();

			await expect(vesting.renounceOwnership()) //
				.to.emit(vesting, 'OwnershipTransferred')
				.withArgs(deployer.address, ZERO_ADDRESS);
			const owner = await vesting.owner();

			expect(owner).to.equal(ZERO_ADDRESS);
			await expect(vesting.transferOwnership(a0.address)).to.be.revertedWith('Ownable: caller is not the owner');
		});
	});

	describe('getPriorVotes - vested', () => {
		it('returns the latest block if >= last checkpoint block', async () => {
			const [, , , a1, a2] = await ethers.getSigners();

			const timestampNow = new Date().getTime();
			const vestingTime = BigNumber.from(timestampNow).mul(2);

			const t1 = await vesting.vest(vestingTime);
			await network.provider.send('evm_mine');
			await network.provider.send('evm_mine');

			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t1.blockNumber))).to.eql(TOTAL_SUPPLY);
			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t1.blockNumber).add(1))).to.eql(TOTAL_SUPPLY);

			const t2 = await vesting.connect(a1).changeBeneficiary(a2.address);
			await network.provider.send('evm_mine');
			await network.provider.send('evm_mine');

			expect(await shibui.getPriorVotes(a2.address, BigNumber.from(t2.blockNumber))).to.eql(TOTAL_SUPPLY);
			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t2.blockNumber))).to.eql(BigNumber.from(0));
			expect(await shibui.getPriorVotes(a2.address, BigNumber.from(t2.blockNumber).add(1))).to.eql(TOTAL_SUPPLY);
			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t2.blockNumber).add(1))).to.eql(BigNumber.from(0));
		});
	});
});
