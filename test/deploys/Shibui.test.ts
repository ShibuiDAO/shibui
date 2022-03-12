import chai, { expect } from 'chai';
import { solidity } from 'ethereum-waffle';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import type { Shibui__factory } from '../../typechain';

chai.use(solidity);

describe('Deploy - "Shibui"', () => {
	it('should deploy', async () => {
		const ShibuiContract = (await ethers.getContractFactory('Shibui')) as Shibui__factory;
		const Shibui = await ShibuiContract.deploy();
		await Shibui.deployed();

		// TESTING DEPLOYED STATE

		const [deployer] = await ethers.getSigners();

		expect(await Shibui.totalSupply()).to.eql(BigNumber.from(0));

		expect(await Shibui.owner()).to.be.equal(deployer.address);
	});
});
