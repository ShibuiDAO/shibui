import chai, { expect } from 'chai';
import { solidity } from 'ethereum-waffle';
import { ethers } from 'hardhat';
import { WEEK_IN_SECONDS, ZERO_ADDRESS } from '../constants';
import type { Timelock, Timelock__factory } from '../typechain';

chai.use(solidity);

describe('Timelock', () => {
	let timelock: Timelock;

	beforeEach(async () => {
		const TimelockContract = (await ethers.getContractFactory('Timelock')) as Timelock__factory;
		timelock = await TimelockContract.deploy(WEEK_IN_SECONDS);
		await timelock.deployed();
	});

	describe('ownable', () => {
		it('should swap ownership', async () => {
			const [deployer, , a0] = await ethers.getSigners();

			await expect(timelock.proposeOwner(a0.address)) //
				.to.emit(timelock, 'OwnerProposed')
				.withArgs(a0.address, deployer.address);
			await expect(timelock.connect(a0).proposedOwnerAccept()) //
				.to.emit(timelock, 'OwnershipTransferred')
				.withArgs(deployer.address, a0.address);

			const owner = await timelock.owner();

			expect(owner).to.equal(a0.address);
		});

		it('should fail to swap ownership', async () => {
			const [, , a0] = await ethers.getSigners();

			await expect(timelock.connect(a0).transferOwnership(a0.address)).to.be.revertedWith('TERMINATED');
			await expect(timelock.connect(a0).proposeOwner(a0.address)).to.be.revertedWith('CALLER_NOT_PERMITTED');
		});

		it('should renounce ownership', async () => {
			const [deployer, , a0] = await ethers.getSigners();

			await expect(timelock.renounceOwnership()) //
				.to.emit(timelock, 'OwnershipTransferred')
				.withArgs(deployer.address, ZERO_ADDRESS);
			const owner = await timelock.owner();

			expect(owner).to.equal(ZERO_ADDRESS);
			await expect(timelock.proposeOwner(a0.address)).to.be.revertedWith('CALLER_NOT_PERMITTED');
		});
	});
});
