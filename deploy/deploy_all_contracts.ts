import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Contract } from "ethers";
import fs from 'fs'
import { parseUnits } from 'ethers';
import path from "path";
/**
 * Deploys a contract named "YourContract" using the deployer account and
 * constructor arguments set to the deployer address
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deployYourContract: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  /*
    On localhost, the deployer account is the one that comes with Hardhat, which is already funded.

    When deploying to live networks (e.g `yarn deploy --network sepolia`), the deployer account
    should have sufficient balance to pay for the gas fees for contract creation.

    You can generate a random account with `yarn generate` or `yarn account:import` to import your
    existing PK which will fill DEPLOYER_PRIVATE_KEY_ENCRYPTED in the .env file (then used on hardhat.config.ts)
    You can run the `yarn account` command to check your balance in every network.
  */
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  type deployedContracts = {
    AccessManager: string,
    SignatureManager: string,
    TokenManager: string,
    SubscriptionManager: string,
    SahaaiManager: string
  }
  let DeployedContracts: deployedContracts = {
    AccessManager: "0x0000000000000000000000000000000000000000", SignatureManager: "0x0000000000000000000000000000000000000000",
    SubscriptionManager: "0x0000000000000000000000000000000000000000", TokenManager: "0x0000000000000000000000000000000000000000",
    SahaaiManager: "0x0000000000000000000000000000000000000000"
  }
  //Deploy the accessManager
  const accessRes = await deploy("AccessManager", {
    from: deployer,
    // Contract constructor arguments
    args: [deployer],
    log: true,
    // autoMine: can be passed to the deploy function to make the deployment process faster on local networks by
    // automatically mining the contract deployment transaction. There is no effect on live networks.
    autoMine: true,
  });
  console.log("Access Manager deployed at Address:", accessRes.address)
  DeployedContracts.AccessManager = accessRes.address;

  const signRes = await deploy("SignatureManager", {
    from: deployer,
    args: ["sahaai", "1"],
    log: true,
    // autoMine: can be passed to the deploy function to make the deployment process faster on local networks by
    // automatically mining the contract deployment transaction. There is no effect on live networks.
    autoMine: true,
  })

  console.log("Signature Manager deployed at Address:", signRes.address)
  DeployedContracts.SignatureManager = signRes.address;

  const subRes = await deploy("SubscriptionManager", {
    from: deployer,
    args: [parseUnits("0.001"), parseUnits("0.005"), parseUnits("0.015"), BigInt(2600000)],
    log: true,
    // autoMine: can be passed to the deploy function to make the deployment process faster on local networks by
    // automatically mining the contract deployment transaction. There is no effect on live networks.
    autoMine: true,
  })
  console.log("SubscriptionManager deployed at Address: ", subRes.address)
  DeployedContracts.SubscriptionManager = subRes.address;

  const tokenRes = await deploy("TokenManager", {
    from: deployer,
    args: [deployer, DeployedContracts.AccessManager],
    log: true,
    // autoMine: can be passed to the deploy function to make the deployment process faster on local networks by
    // automatically mining the contract deployment transaction. There is no effect on live networks.
    autoMine: true,
  })
  console.log("Token Manager Deployed at Address:", tokenRes.address)
  DeployedContracts.TokenManager = tokenRes.address;
  const sahaaiRes = await deploy("SahaaiManager", {
    from: deployer,
    args: ["sahaai", "S", DeployedContracts.SubscriptionManager, DeployedContracts.SignatureManager, DeployedContracts.TokenManager, DeployedContracts.AccessManager],
    log: true,
    // autoMine: can be passed to the deploy function to make the deployment process faster on local networks by
    // automatically mining the contract deployment transaction. There is no effect on live networks.
    autoMine: true,
  })
  console.log("Sahaai Manager Deployed at Address:", sahaaiRes.address)
  DeployedContracts.SahaaiManager = sahaaiRes.address;
  const filePath = path.join(`./deployments/${hre.network.name}`
    , "deployments.json");
  fs.writeFileSync(filePath, JSON.stringify(DeployedContracts), 'utf8')

  const TokenManagerContract = await hre.ethers.getContractAt("TokenManager", deployer);
  const result = await (await TokenManagerContract.authorizeSpender(DeployedContracts.SahaaiManager)).wait()
  console.log("set the authorized spender ", result, DeployedContracts);


};

export default deployYourContract;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags YourContract
deployYourContract.tags = ["Sahaai-Contracts"];
