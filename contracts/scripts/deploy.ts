import { ethers, network } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(`Network: ${network.name}`);
  console.log(`Deployer: ${deployer.address}`);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(`Deployer balance: ${ethers.formatEther(balance)} ETH`);

  const ReputationSystem = await ethers.getContractFactory("ReputationSystem");
  const reputationSystem = await ReputationSystem.deploy();
  await reputationSystem.waitForDeployment();
  const reputationSystemAddress = await reputationSystem.getAddress();

  const WorldCupBetting = await ethers.getContractFactory("WorldCupBetting");
  const worldCupBetting = await WorldCupBetting.deploy(reputationSystemAddress);
  await worldCupBetting.waitForDeployment();
  const worldCupBettingAddress = await worldCupBetting.getAddress();

  const setMarketTx = await reputationSystem.setPredictionMarket(worldCupBettingAddress);
  await setMarketTx.wait();

  console.log("Deployment complete:");
  console.log(`ReputationSystem: ${reputationSystemAddress}`);
  console.log(`WorldCupBetting: ${worldCupBettingAddress}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
