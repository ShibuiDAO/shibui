import type { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { HDNode } from 'ethers/lib/utils';
import type { HardhatNetworkHDAccountsUserConfig } from 'hardhat/types';
import config from '../../hardhat.config';

export type SignerWithAddressAndPrivateKey = SignerWithAddress & { privateKey: string };

export function getSignersWithPrivateKeys(signers: SignerWithAddress[]): SignerWithAddressAndPrivateKey[] {
	const expandedSigners: SignerWithAddressAndPrivateKey[] = [];

	const hhHDConfig = config.networks!.hardhat!.accounts as HardhatNetworkHDAccountsUserConfig;
	const hd = HDNode.fromMnemonic(hhHDConfig.mnemonic!);

	for (let i = 0; i < signers.length; i++) {
		const signer = signers[i] as SignerWithAddressAndPrivateKey;
		const wallet = hd.derivePath(`${hhHDConfig.path!}/${i}`);

		signer.privateKey = wallet.privateKey;
		expandedSigners.push(signer);
	}

	return expandedSigners;
}
