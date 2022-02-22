import chai, { expect } from 'chai';
import { solidity } from 'ethereum-waffle';
import type { Shibui, Shibui__factory } from '../typechain';
import { ethers, network } from 'hardhat';
import { BigNumber, ContractTransaction } from 'ethers';
import { promisify } from 'util';

chai.use(solidity);

const queue = promisify(setImmediate);

async function countPendingTransactions() {
	// eslint-disable-next-line radix
	return parseInt(await network.provider.send('eth_getBlockTransactionCountByNumber', ['pending']));
}

export type WrappedUnresolvedContractTransaction = () => Promise<ContractTransaction>;

async function batchInBlock(txs: WrappedUnresolvedContractTransaction[]) {
	try {
		// disable auto-mining
		await network.provider.send('evm_setAutomine', [false]);
		// send all transactions
		const promises = txs.map((fn) => fn());
		// wait for node to have all pending transactions
		while (txs.length > (await countPendingTransactions())) {
			await queue();
		}
		// mine one block
		await network.provider.send('evm_mine');
		// fetch receipts
		const receipts = await Promise.all(promises);
		// Sanity check, all tx should be in the same block
		const minedBlocks = new Set(receipts.map((receipt) => receipt.blockNumber));
		expect(minedBlocks.size).to.equal(1);

		return receipts;
	} finally {
		// enable auto-mining
		await network.provider.send('evm_setAutomine', [true]);
	}
}

describe('Shibui', () => {
	const NAME = 'Shibui';
	const SYMBOL = '🌊';

	let shibui: Shibui;

	beforeEach(async () => {
		const [_, minter] = await ethers.getSigners();

		const ShibuiContract = (await ethers.getContractFactory('Shibui')) as Shibui__factory;
		shibui = await ShibuiContract.deploy(minter.address);
	});

	describe('metadata', () => {
		it('has given name', async () => {
			expect(await shibui.name()).to.equal(NAME);
		});

		it('has given symbol', async () => {
			expect(await shibui.symbol()).to.equal(SYMBOL);
		});
	});

	describe('balanceOf', () => {
		it('grants to initial account', async () => {
			const [_, minter] = await ethers.getSigners();
			const minterBalance = await shibui.balanceOf(minter.address);

			expect(minterBalance.toString()).to.equal(BigNumber.from(10).pow(18).mul(50_000_000).toString());
		});
	});

	describe('numCheckpoints', () => {
		it('returns the number of checkpoints for a delegate', async () => {
			const [_, minter, a0, a1, a2] = await ethers.getSigners();
			await shibui.connect(minter).transfer(a0.address, 100);
			expect(await shibui.numCheckpoints(a1.address)).to.equal(0);

			const t1 = await shibui.connect(a0).delegate(a1.address);
			expect(await shibui.numCheckpoints(a1.address)).to.equal(1);

			const t2 = await shibui.connect(a0).transfer(a2.address, 10);
			expect(await shibui.numCheckpoints(a1.address)).to.equal(2);

			const t3 = await shibui.connect(a0).transfer(a2.address, 10);
			expect(await shibui.numCheckpoints(a1.address)).to.equal(3);

			const t4 = await shibui.connect(minter).transfer(a0.address, 20);
			expect(await shibui.numCheckpoints(a1.address)).to.equal(4);

			expect(await shibui.checkpoints(a1.address, 0)).to.eql([t1.blockNumber, BigNumber.from(100)]);
			expect(await shibui.checkpoints(a1.address, 1)).to.eql([t2.blockNumber, BigNumber.from(90)]);
			expect(await shibui.checkpoints(a1.address, 2)).to.eql([t3.blockNumber, BigNumber.from(80)]);
			expect(await shibui.checkpoints(a1.address, 3)).to.eql([t4.blockNumber, BigNumber.from(100)]);
		});

		it('does not add more than one checkpoint in a block', async () => {
			const [_, minter, a0, a1, a2] = await ethers.getSigners();

			await shibui.connect(minter).transfer(a0.address, 100);
			expect(await shibui.numCheckpoints(a1.address)).to.equal(0);

			const [t1] = await batchInBlock([
				() => shibui.connect(a0).delegate(a1.address),
				() => shibui.connect(a0).transfer(a2.address, 10),
				() => shibui.connect(a0).transfer(a2.address, 10)
			]);

			expect(await shibui.numCheckpoints(a1.address)).to.equal(1);

			expect(await shibui.checkpoints(a1.address, 0)).to.eql([t1.blockNumber, BigNumber.from(80)]);
			expect(await shibui.checkpoints(a1.address, 1)).to.eql([0, BigNumber.from(0)]);
			expect(await shibui.checkpoints(a1.address, 2)).to.eql([0, BigNumber.from(0)]);

			const t4 = await shibui.connect(minter).transfer(a0.address, 20);
			expect(await shibui.numCheckpoints(a1.address)).to.equal(2);
			expect(await shibui.checkpoints(a1.address, 1)).to.eql([t4.blockNumber, BigNumber.from(100)]);
		});
	});
});
