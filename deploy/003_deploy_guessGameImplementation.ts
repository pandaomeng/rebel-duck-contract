import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
// eslint-disable-next-line node/no-unpublished-import
import { useLogger } from '../scripts/utils'
import { HardhatDeployRuntimeEnvironment } from '../types/hardhat-deploy'
import { advancedDeploy } from './.defines'
import { exec } from 'child_process'
import { StakeFactoryNames } from './002_deploy_guessGameFactory'

const logger = useLogger(__filename)

export enum ImplementationNames {
  GuessGame = 'GuessGame',
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre as unknown as HardhatDeployRuntimeEnvironment
  const { deploy, execute } = deployments

  const { deployer } = await getNamedAccounts()

  const execOptions = {
    from: deployer,
    gasLimit: 30000000,
  }
  const guessGame = await advancedDeploy(
    {
      hre,
      logger,
      name: ImplementationNames.GuessGame,
    },
    async ({ name }) => {
      return await deploy(name, {
        from: deployer,
        contract: name,
        log: true,
        autoMine: true, // speed up deployment on local network (ganache, hardhat), no effect on live networks
      })
    },
  )
  if (guessGame.newlyDeployed) {
    logger.info('setImplementation')
    await execute(StakeFactoryNames.Factory, execOptions, 'setStakeImplementation', guessGame.address, true)
  }
}
export default func
