import chai, { expect } from 'chai';
import { solidity } from 'ethereum-waffle';
import { BigNumber } from 'ethers';
import { ethers, network } from 'hardhat';
import { BOBA_DAO_DISTRIBUTION } from '../../constants';
import type { Shibui, Shibui__factory } from '../../typechain';

chai.use(solidity);

describe('Distribute - "BobaDAO"', () => {
	it('should execute', async () => {
		const [deployer, , bobaDAO, a1] = await ethers.getSigners();

		// PREP PRE SCRIPT STATE

		const ShibuiContract = (await ethers.getContractFactory('Shibui')) as Shibui__factory;
		const _Shibui = await ShibuiContract.deploy();
		await _Shibui.deployed();

		// SCRIPT LOGIC

		const Shibui = (await ethers.getContractAt('Shibui', _Shibui.address)) as Shibui;

		await Shibui.connect(deployer).lockHolder(bobaDAO.address);
		await Shibui.connect(deployer).mintAmount(bobaDAO.address, BOBA_DAO_DISTRIBUTION);

		// TESTING DEPLOYED STATE

		// const blockNumberBeforeMine = await ethers.provider.getBlockNumber();
		await network.provider.send('evm_mine');
		// const blockNumberAfterMine = await ethers.provider.getBlockNumber();

		expect(await Shibui.balanceOf(bobaDAO.address)).to.eql(BOBA_DAO_DISTRIBUTION);
		await expect(Shibui.connect(bobaDAO).transfer(a1.address, BigNumber.from(BOBA_DAO_DISTRIBUTION).div(2))).to.be.revertedWith(
			'HOLDER_LOCKED_FROM_TRANSFER'
		);
		expect(await Shibui.balanceOf(a1.address)).to.eql(BigNumber.from(0));
	});
});
