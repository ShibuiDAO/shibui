import chai, { expect } from 'chai';
import { solidity } from 'ethereum-waffle';
import { BigNumber, ContractTransaction } from 'ethers';
import { randomBytes } from 'ethers/lib/utils';
import { ethers, network } from 'hardhat';
import { promisify } from 'util';
import type { Shibui, Shibui__factory } from '../typechain';
import * as ethSigUtil from 'eth-sig-util';
import { fromRpcSig } from 'ethereumjs-util';
import { getSignersWithPrivateKeys } from './utilities/privateKeys';

chai.use(solidity);

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
// const MAX_UINT256 = BigNumber.from(2).pow(256).sub(1);
const MAX_JS_NUMBER = Number.MAX_SAFE_INTEGER;

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
	let shibui: Shibui;

	const NAME = 'Shibui';
	const SYMBOL = '🌊';
	const TOTAL_SUPPLY = BigNumber.from(10).pow(18).mul(50_000_000);

	beforeEach(async () => {
		const [, minter] = await ethers.getSigners();

		const ShibuiContract = (await ethers.getContractFactory('Shibui')) as Shibui__factory;
		shibui = await ShibuiContract.deploy();
		await shibui.deployed();

		await shibui.fullMint(minter.address);
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
			const [, minter] = await ethers.getSigners();
			const minterBalance = await shibui.balanceOf(minter.address);

			expect(minterBalance).to.eql(TOTAL_SUPPLY);
		});
	});

	describe('fullMint', () => {
		it('should fail to mint again', async () => {
			const [, minter] = await ethers.getSigners();

			await expect(shibui.fullMint(minter.address)).to.be.revertedWith('MINT_EXECUTED');
		});
	});

	describe('ownable', () => {
		it('should swap ownership', async () => {
			const [deployer, , a0] = await ethers.getSigners();

			await expect(shibui.transferOwnership(a0.address)) //
				.to.emit(shibui, 'OwnershipTransferred')
				.withArgs(deployer.address, a0.address);
			const owner = await shibui.owner();

			expect(owner).to.equal(a0.address);
		});

		it('should fail to swap ownership', async () => {
			const [, , a0] = await ethers.getSigners();

			await expect(shibui.connect(a0).transferOwnership(a0.address)).to.be.revertedWith('Ownable: caller is not the owner');
		});

		it('should renounce ownership', async () => {
			const [deployer, , a0] = await ethers.getSigners();

			await expect(shibui.renounceOwnership()) //
				.to.emit(shibui, 'OwnershipTransferred')
				.withArgs(deployer.address, ZERO_ADDRESS);
			const owner = await shibui.owner();

			expect(owner).to.equal(ZERO_ADDRESS);
			await expect(shibui.transferOwnership(a0.address)).to.be.revertedWith('Ownable: caller is not the owner');
		});
	});

	describe('delegateBySig', () => {
		const nonce = BigNumber.from(0);

		const EIP712Domain = [
			{ name: 'name', type: 'string' },
			{ name: 'version', type: 'string' },
			{ name: 'chainId', type: 'uint256' },
			{ name: 'verifyingContract', type: 'address' }
		];

		const Delegation = [
			{ name: 'delegatee', type: 'address' },
			{ name: 'nonce', type: 'uint256' },
			{ name: 'expiry', type: 'uint256' }
		];

		const buildData = (chainId: number, verifyingContract: string, message: any) => ({
			data: {
				primaryType: 'Delegation' as const,
				types: { EIP712Domain, Delegation },
				domain: { name: NAME, version: '1', chainId, verifyingContract },
				message
			}
		});

		it('reverts if the signatory is invalid', async () => {
			const [, minter, a0] = await ethers.getSigners();
			const expiry = BigNumber.from(0);

			await expect(shibui.connect(minter).delegateBySig(a0.address, nonce, expiry, 0, randomBytes(32), randomBytes(32))).to.be.reverted;
		});

		it('reverts if the nonce is bad', async () => {
			const [, minter, a0] = getSignersWithPrivateKeys(await ethers.getSigners());
			const badNonce = BigNumber.from(nonce).add(1);

			const { v, r, s } = fromRpcSig(
				ethSigUtil.signTypedMessage(
					Buffer.from(minter.privateKey, 'hex'),
					buildData(await minter.getChainId(), shibui.address, {
						delegatee: a0.address,
						nonce: badNonce.toNumber(),
						expiry: MAX_JS_NUMBER
					})
				)
			);

			await expect(shibui.delegateBySig(a0.address, badNonce, BigNumber.from(MAX_JS_NUMBER.toString()), v, r, s)) //
				.to.be.revertedWith('DELEGATE_SIG_INVALID_NONCE');
		});

		it('reverts if the signature has expired', async () => {
			const [, minter, a0] = getSignersWithPrivateKeys(await ethers.getSigners());
			const badExpire = 0;

			const { v, r, s } = fromRpcSig(
				ethSigUtil.signTypedMessage(
					Buffer.from(minter.privateKey, 'hex'),
					buildData(await minter.getChainId(), shibui.address, {
						delegatee: a0.address,
						nonce: nonce.toNumber(),
						expiry: badExpire
					})
				)
			);

			await expect(shibui.delegateBySig(a0.address, nonce, BigNumber.from(badExpire), v, r, s)) //
				.to.be.revertedWith('DELEGATE_SIG_EXPIRED');
		});

		it('delegates on behalf of the signatory', async () => {
			const [, minter, a0] = getSignersWithPrivateKeys(await ethers.getSigners());

			const { v, r, s } = fromRpcSig(
				ethSigUtil.signTypedMessage(
					Buffer.from(minter.privateKey, 'hex'),
					buildData(await minter.getChainId(), shibui.address, {
						delegatee: a0.address,
						nonce: nonce.toNumber(),
						expiry: MAX_JS_NUMBER
					})
				)
			);

			await expect(shibui.delegateBySig(a0.address, nonce, BigNumber.from(MAX_JS_NUMBER.toString()), v, r, s))
				.to.emit(shibui, 'DelegateChanged')
				.withArgs(minter.address, ZERO_ADDRESS, a0.address)
				.and //
				.to.emit(shibui, 'DelegateVotesChanged')
				.withArgs(a0.address, BigNumber.from(0), TOTAL_SUPPLY);
			expect(await shibui.getCurrentVotes(a0.address)).to.eql(TOTAL_SUPPLY);
			expect(await shibui.delegates(minter.address)).to.equal(a0.address);
		});
	});

	describe('numCheckpoints', () => {
		it('returns the number of checkpoints for a delegate', async () => {
			const [, minter, a0, a1, a2] = await ethers.getSigners();
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
			const [, minter, a0, a1, a2] = await ethers.getSigners();

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

	describe('getPriorVotes', () => {
		it('reverts if block number >= current block', async () => {
			const [, , , a1] = await ethers.getSigners();

			await expect(shibui.getPriorVotes(a1.address, 5e10)).to.revertedWith('VOTES_NOT_YET_DETERMINED');
		});

		it('returns 0 if there are no checkpoints', async () => {
			const [, , , a1] = await ethers.getSigners();

			expect(await shibui.getPriorVotes(a1.address, 0)).to.eql(BigNumber.from(0));
		});

		it('returns the latest block if >= last checkpoint block', async () => {
			const [, minter, , a1] = await ethers.getSigners();

			const t1 = await shibui.connect(minter).delegate(a1.address);
			await network.provider.send('evm_mine');
			await network.provider.send('evm_mine');

			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t1.blockNumber))).to.eql(TOTAL_SUPPLY);
			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t1.blockNumber).add(1))).to.eql(TOTAL_SUPPLY);
		});

		it('returns zero if < first checkpoint block', async () => {
			const [, minter, , a1] = await ethers.getSigners();

			await network.provider.send('evm_mine');
			const t1 = await shibui.connect(minter).delegate(a1.address);
			await network.provider.send('evm_mine');
			await network.provider.send('evm_mine');

			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t1.blockNumber).sub(1))).to.eql(BigNumber.from(0));
			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t1.blockNumber).add(1))).to.eql(TOTAL_SUPPLY);
		});

		it('generally returns the voting balance at the appropriate checkpoint', async () => {
			const [, minter, , a1, a2] = await ethers.getSigners();

			const t1 = await shibui.connect(minter).delegate(a1.address);
			await network.provider.send('evm_mine');
			await network.provider.send('evm_mine');
			const t2 = await shibui.connect(minter).transfer(a2.address, 10);
			await network.provider.send('evm_mine');
			await network.provider.send('evm_mine');
			const t3 = await shibui.connect(minter).transfer(a2.address, 10);
			await network.provider.send('evm_mine');
			await network.provider.send('evm_mine');
			const t4 = await shibui.connect(a2).transfer(minter.address, 20);
			await network.provider.send('evm_mine');
			await network.provider.send('evm_mine');

			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t1.blockNumber).sub(1))).to.eql(BigNumber.from(0));
			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t1.blockNumber))).to.eql(TOTAL_SUPPLY);
			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t1.blockNumber).add(1))).to.eql(TOTAL_SUPPLY);
			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t2.blockNumber))).to.eql(TOTAL_SUPPLY.sub(10));
			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t2.blockNumber).add(1))).to.eql(TOTAL_SUPPLY.sub(10));
			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t3.blockNumber))).to.eql(TOTAL_SUPPLY.sub(20));
			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t3.blockNumber).add(1))).to.eql(TOTAL_SUPPLY.sub(20));
			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t4.blockNumber))).to.eql(TOTAL_SUPPLY);
			expect(await shibui.getPriorVotes(a1.address, BigNumber.from(t4.blockNumber).add(1))).to.eql(TOTAL_SUPPLY);
		});
	});

	describe('lockedHolders', () => {
		it('should store locked holder', async () => {
			const [deployer, , a0] = await ethers.getSigners();

			expect(await shibui.lockedHolders(a0.address)).to.equal(false);

			await expect(shibui.lockHolder(a0.address)) //
				.to.emit(shibui, 'HolderLocked')
				.withArgs(a0.address, deployer.address);

			expect(await shibui.lockedHolders(a0.address)).to.equal(true);

			await expect(shibui.unlockHolder(a0.address)) //
				.to.emit(shibui, 'HolderUnlocked')
				.withArgs(a0.address, deployer.address);

			expect(await shibui.lockedHolders(a0.address)).to.equal(false);
		});

		it('should prevent transfer', async () => {
			const [deployer, minter, a0, a1] = await ethers.getSigners();

			await shibui.connect(minter).transfer(a0.address, 100);

			await expect(shibui.lockHolder(a0.address)) //
				.to.emit(shibui, 'HolderLocked')
				.withArgs(a0.address, deployer.address);

			await expect(shibui.connect(a0).transfer(a1.address, 50)).to.revertedWith('HOLDER_LOCKED_FROM_TRANSFER');
		});
	});
});
