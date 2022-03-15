import chai, { expect } from 'chai';
import { solidity } from 'ethereum-waffle';
import { ethers, network } from 'hardhat';
import { OOLONG_PAIR_CREATION_DISTRIBUTION } from '../../constants';
import type { Shibui, Shibui__factory } from '../../typechain';

chai.use(solidity);

describe('Distribute - "OolongPairCreation"', () => {
	it('should execute', async () => {
		const [deployer] = await ethers.getSigners();

		// PREP PRE SCRIPT STATE

		const ShibuiContract = (await ethers.getContractFactory('Shibui')) as Shibui__factory;
		const _Shibui = await ShibuiContract.deploy();
		await _Shibui.deployed();

		// SCRIPT LOGIC

		const Shibui = (await ethers.getContractAt('Shibui', _Shibui.address)) as Shibui;

		await Shibui.connect(deployer).mintAmount(deployer.address, OOLONG_PAIR_CREATION_DISTRIBUTION);

		// TESTING DEPLOYED STATE

		// const blockNumberBeforeMine = await ethers.provider.getBlockNumber();
		await network.provider.send('evm_mine');
		// const blockNumberAfterMine = await ethers.provider.getBlockNumber();

		expect(await Shibui.balanceOf(deployer.address)).to.eql(OOLONG_PAIR_CREATION_DISTRIBUTION);
	});
});
