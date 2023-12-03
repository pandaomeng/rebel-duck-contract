import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
// eslint-disable-next-line node/no-unpublished-import
import { useLogger } from "../scripts/utils";
import { HardhatDeployRuntimeEnvironment } from "../types/hardhat-deploy";
import { advancedDeploy } from "./.defines";
import { exec } from "child_process";
import { StakeFactoryNames } from "./002_deploy_guessGameFactory";

const logger = useLogger(__filename);

export enum ImplementationNames {
  MockERC20 = "MockERC20",
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } =
    hre as unknown as HardhatDeployRuntimeEnvironment;
  const { deploy, execute } = deployments;

  const { deployer } = await getNamedAccounts();

  const execOptions = {
    from: deployer,
    gasLimit: 30000000,
  };
  const erc20 = await advancedDeploy(
    {
      hre,
      logger,
      name: ImplementationNames.MockERC20,
    },
    async ({ name }) => {
      return await deploy(name, {
        from: deployer,
        contract: name,
        log: true,
        autoMine: true,
        args: ["MockERC20", "MockERC20"],
      });
    }
  );
};
export default func;
