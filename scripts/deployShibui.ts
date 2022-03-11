import { ethers } from 'hardhat';
import ora from 'ora';
import type { Shibui__factory } from '../typechain';

async function main() {
	const spinner = ora('Deploying contracts').start();
	const [deployer] = await ethers.getSigners();

	spinner.text = 'Deploying "Shibui" contract';
	const ShibuiContract = (await ethers.getContractFactory('Shibui')) as Shibui__factory;
	const Shibui = await ShibuiContract.deploy();
	await Shibui.deployed();

	spinner.succeed();

	console.log(
		[
			'',
			` - "Shibui" deployed to ${Shibui.address}`, //
			`Deployer address is ${deployer.address}`
		].join('\n')
	);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
